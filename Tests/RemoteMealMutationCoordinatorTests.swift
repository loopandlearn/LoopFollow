// LoopFollow
// RemoteMealMutationCoordinatorTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct RemoteMealMutationCoordinatorTests {
    private let commandID = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
    private let mealID = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("APNs acceptance means awaiting Trio, not applied")
    func transportAcceptanceIsNotApplication() {
        let sending = operation(state: .sending)
        let awaiting = TRCMealMutationReducer.reduce(sending, event: .transportAccepted, at: now)

        #expect(awaiting.state == .awaiting)
        #expect(awaiting.responseResult == nil)
        #expect(awaiting.blocksActions)
        #expect(TRCMealMutationReducer.reduce(awaiting, event: .transportAccepted, at: now) == awaiting)
    }

    @Test("A persisted sending attempt can time out and become retryable")
    func interruptedSendingAttemptCanRecover() {
        let sending = operation(state: .sending)
        let timedOut = TRCMealMutationReducer.reduce(sending, event: .timedOut, at: now)

        #expect(timedOut.state == .timedOut)
        #expect(timedOut.isRetryable)
        #expect(timedOut.blocksActions)
    }

    @Test("Coordinator startup recovers expired persisted attempts")
    @MainActor
    func startupRecoversExpiredAttempt() {
        let sending = operation(state: .sending)
        let storage = StorageValue<[TRCMealMutationOperation]>(
            key: "RemoteMealMutationCoordinatorTests-\(UUID().uuidString)",
            defaultValue: [sending]
        )
        defer { storage.remove() }

        let coordinator = TRCMealMutationCoordinator(storage: storage, transport: { _, _ in }, at: now)
        let recovered = coordinator.operations[0]

        #expect(recovered.state == .timedOut)
        #expect(recovered.isRetryable)
        #expect(storage.value == [recovered])
    }

    @Test("Every Trio result reduces to its contract state")
    func resultStates() {
        let expectedStates: [(TRCMealMutationResult, TRCMealMutationState)] = [
            (.updated, .applied),
            (.deleted, .applied),
            (.alreadyApplied, .applied),
            (.rejected, .rejected),
            (.inProgress, .inProgress),
        ]

        for (result, expectedState) in expectedStates {
            let reduced = TRCMealMutationReducer.reduce(
                operation(state: .awaiting),
                event: .response(
                    result: result,
                    syncStatus: .requested,
                    body: "Trio response",
                    timestamp: now.timeIntervalSince1970
                ),
                at: now
            )

            #expect(reduced.state == expectedState)
            #expect(reduced.responseResult == result)
            #expect(reduced.syncStatus == .requested)
            #expect(reduced.responseBody == "Trio response")
        }
    }

    @Test("Response decoding uses result and supports both sync states")
    func responseDecoding() {
        for result in ["updated", "deleted", "already_applied", "rejected", "in_progress"] {
            for syncStatus in ["requested", "not_requested"] {
                let response = TRCMealMutationResponse(userInfo: [
                    "command_status": result == "in_progress" ? "failed" : "success",
                    "command_type": "edit_meal",
                    "command_id": commandID.lowercased(),
                    "meal_id": mealID.lowercased(),
                    "result": result,
                    "sync_status": syncStatus,
                    "timestamp": 1_800_000_005,
                    "aps": ["alert": ["body": "Meal response"]],
                ])

                #expect(response.result?.rawValue == result)
                #expect(response.syncStatus?.rawValue == syncStatus)
                #expect(response.body == "Meal response")
                #expect(response.timestamp == 1_800_000_005)
                #expect(response.matches(operation(state: .awaiting)))
            }
        }
    }

    @Test("Correlation requires command type and both canonical UUIDs")
    func strictCorrelation() {
        let pending = operation(state: .awaiting)
        let matching = response()

        #expect(matching.matches(pending))
        #expect(!response(commandType: "delete_meal").matches(pending))
        #expect(!response(commandID: "33333333-3333-3333-3333-333333333333").matches(pending))
        #expect(!response(mealID: "33333333-3333-3333-3333-333333333333").matches(pending))
        #expect(!response(commandID: nil).matches(pending))
        #expect(!response(mealID: nil).matches(pending))
    }

    @Test("Terminal results absorb duplicates and later contradictory delivery")
    func terminalResultsAreAbsorbing() {
        let pending = operation(state: .awaiting)
        let applied = TRCMealMutationReducer.reduce(
            pending,
            event: .response(result: .updated, syncStatus: .requested, body: "Updated", timestamp: 200),
            at: now
        )
        let duplicate = TRCMealMutationReducer.reduce(
            applied,
            event: .response(result: .updated, syncStatus: .requested, body: "Updated", timestamp: 200),
            at: now.addingTimeInterval(1)
        )
        let contradictory = TRCMealMutationReducer.reduce(
            applied,
            event: .response(result: .inProgress, syncStatus: nil, body: "Still processing", timestamp: 201),
            at: now.addingTimeInterval(1)
        )

        #expect(duplicate == applied)
        #expect(contradictory == applied)

        let rejected = TRCMealMutationReducer.reduce(
            pending,
            event: .response(result: .rejected, syncStatus: .notRequested, body: "Stale meal", timestamp: 200),
            at: now
        )
        #expect(TRCMealMutationReducer.reduce(
            rejected,
            event: .response(result: .updated, syncStatus: .requested, body: "Updated", timestamp: 201),
            at: now.addingTimeInterval(1)
        ) == rejected)
    }

    @Test("Older nonterminal responses cannot replace newer response state")
    func outOfOrderResponseIsIgnored() {
        let inProgress = TRCMealMutationReducer.reduce(
            operation(state: .awaiting),
            event: .response(result: .inProgress, syncStatus: nil, body: "Working", timestamp: 300),
            at: now
        )
        let older = TRCMealMutationReducer.reduce(
            inProgress,
            event: .response(result: .rejected, syncStatus: nil, body: "Old rejection", timestamp: 299),
            at: now.addingTimeInterval(1)
        )

        #expect(older == inProgress)
    }

    @Test("A duplicate in-progress response cannot undo a retry attempt")
    func duplicateInProgressDoesNotUndoRetry() {
        let original = operation(state: .inProgress)
        let retry = TRCMealMutationReducer.reduce(original, event: .retryStarted, at: now)
        let duplicate = TRCMealMutationReducer.reduce(
            retry,
            event: .response(
                result: .inProgress,
                syncStatus: nil,
                body: "Working",
                timestamp: 1_800_000_001
            ),
            at: now.addingTimeInterval(1)
        )

        #expect(duplicate == retry)
        #expect(duplicate.state == .sending)
    }

    @Test("Retry preserves the logical mutation and refreshes only attempt time")
    func retryPreservesLogicalMutation() {
        let original = operation(state: .inProgress)
        let retryDate = now.addingTimeInterval(60)
        let retry = TRCMealMutationReducer.reduce(original, event: .retryStarted, at: retryDate)
        let request = retry.transportRequest(at: retryDate)

        #expect(retry.state == .sending)
        #expect(retry.commandID == original.commandID)
        #expect(retry.mealID == original.mealID)
        #expect(retry.user == original.user)
        #expect(retry.type == original.type)
        #expect(retry.expected == original.expected)
        #expect(retry.replacement == original.replacement)
        #expect(retry.createdAt == original.createdAt)
        #expect(retry.lastAttemptAt == retryDate)
        #expect(request.commandID == original.commandID)
        #expect(request.mealID == original.mealID)
        #expect(request.user == original.user)
        #expect(request.expected == original.expected)
        #expect(request.replacement == original.replacement)
        #expect(request.transportTimestamp == retryDate.timeIntervalSince1970)
    }

    @Test("A stale transport completion cannot overwrite a newer retry")
    @MainActor
    func staleTransportCompletionIsIgnored() throws {
        let storage = StorageValue<[TRCMealMutationOperation]>(
            key: "RemoteMealMutationCoordinatorTests-\(UUID().uuidString)",
            defaultValue: []
        )
        defer { storage.remove() }

        var completions: [(Bool, String?) -> Void] = []
        let coordinator = TRCMealMutationCoordinator(storage: storage, transport: { _, completion in
            completions.append(completion)
        }, at: now)
        let started = try coordinator.startEdit(
            mealID: mealID,
            user: "Original User",
            expectedCarbs: 30,
            expectedFat: 10,
            expectedProtein: 5,
            expectedMealTime: now.timeIntervalSince1970,
            carbs: 25,
            fat: 12,
            protein: 6,
            scheduledTime: now.timeIntervalSince1970,
            at: now
        )

        coordinator.markTimedOut(
            commandID: started.commandID,
            at: now.addingTimeInterval(TRCMealMutationCoordinator.attemptTimeout)
        )
        let retryDate = now.addingTimeInterval(TRCMealMutationCoordinator.attemptTimeout + 1)
        _ = try coordinator.retry(commandID: started.commandID, at: retryDate)

        #expect(completions.count == 2)
        completions[0](false, "Late failure from first attempt")
        #expect(coordinator.operation(commandID: started.commandID)?.state == .sending)
        completions[1](true, nil)
        #expect(coordinator.operation(commandID: started.commandID)?.state == .awaiting)
    }

    @Test("Initial validation accepts exact boundaries, generates IDs, and persists before transport")
    @MainActor
    func newMutationsAreUniqueAndPersistBeforeTransport() throws {
        let storage = StorageValue<[TRCMealMutationOperation]>(
            key: "RemoteMealMutationCoordinatorTests-\(UUID().uuidString)",
            defaultValue: []
        )
        defer { storage.remove() }

        var sentRequests: [TRCMealMutationTransportRequest] = []
        let coordinator = TRCMealMutationCoordinator(storage: storage) { request, _ in
            #expect(storage.value.contains { $0.commandID == request.commandID })
            sentRequests.append(request)
        }

        let first = try coordinator.startEdit(
            mealID: mealID,
            user: "Original User",
            expectedCarbs: 30,
            expectedFat: 10,
            expectedProtein: 5,
            expectedMealTime: now.timeIntervalSince1970 - TRCMealMutationTimePolicy.maximumOffset,
            carbs: 25,
            fat: 12,
            protein: 6,
            scheduledTime: now.timeIntervalSince1970 + TRCMealMutationTimePolicy.maximumOffset,
            at: now
        )
        let second = try coordinator.startDelete(
            mealID: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC",
            user: "Original User",
            expectedCarbs: 20,
            expectedFat: 0,
            expectedProtein: 0,
            expectedMealTime: now.timeIntervalSince1970 - 1800,
            at: now
        )

        #expect(first.commandID != second.commandID)
        #expect(Set(storage.value.map(\.commandID)).count == 2)
        #expect(sentRequests.map(\.commandID) == [first.commandID, second.commandID])
        let firstRequest = try #require(sentRequests.first)
        #expect(firstRequest.commandID == first.commandID)
        #expect(firstRequest.mealID == first.mealID)
        #expect(firstRequest.expected == first.expected)
        #expect(firstRequest.replacement == first.replacement)

        var duplicateError: TRCMealMutationCoordinatorError?
        do {
            _ = try coordinator.startDelete(
                mealID: mealID,
                user: "Original User",
                expectedCarbs: 30,
                expectedFat: 10,
                expectedProtein: 5,
                expectedMealTime: now.timeIntervalSince1970 - 3600,
                at: now
            )
        } catch let error as TRCMealMutationCoordinatorError {
            duplicateError = error
        }
        #expect(duplicateError == .operationAlreadyPending)
    }

    @Test("Applied edits remain blocked until refreshed source values reconcile")
    func reconciliationUnblocksAppliedEdit() {
        let applied = operation(state: .applied)
        let reconciled = TRCMealMutationReducer.reduce(applied, event: .reconciled, at: now)

        #expect(applied.blocksActions)
        #expect(reconciled.state == .applied)
        #expect(reconciled.reconciledAt == now)
        #expect(!reconciled.blocksActions)
    }

    @Test("Source and replacement accept exact past and future twelve-hour boundaries")
    func exactTwelveHourBoundariesAreValid() throws {
        let policy = TRCMealMutationTimePolicy()
        let pastBoundary = now.timeIntervalSince1970 - TRCMealMutationTimePolicy.maximumOffset
        let futureBoundary = now.timeIntervalSince1970 + TRCMealMutationTimePolicy.maximumOffset

        #expect(policy.isValid(pastBoundary, at: now))
        #expect(policy.isValid(futureBoundary, at: now))

        try TRCMealMutationValidator.validate(
            type: .edit,
            expected: values(mealTime: pastBoundary),
            replacement: values(mealTime: futureBoundary),
            at: now
        )
        try TRCMealMutationValidator.validate(
            type: .edit,
            expected: values(mealTime: futureBoundary),
            replacement: values(mealTime: pastBoundary),
            at: now
        )
        try TRCMealMutationValidator.validate(
            type: .delete,
            expected: values(mealTime: futureBoundary),
            replacement: nil,
            at: now
        )
    }

    @Test("Source and replacement reject either side outside twelve hours by epsilon")
    func timestampsOutsideTwelveHoursAreRejected() {
        let policy = TRCMealMutationTimePolicy()
        let epsilon = 0.001
        let pastOutside = now.timeIntervalSince1970 - TRCMealMutationTimePolicy.maximumOffset - epsilon
        let futureOutside = now.timeIntervalSince1970 + TRCMealMutationTimePolicy.maximumOffset + epsilon
        let current = values(mealTime: now.timeIntervalSince1970)

        #expect(!policy.isValid(pastOutside, at: now))
        #expect(!policy.isValid(futureOutside, at: now))
        #expect(validationError(
            expected: values(mealTime: pastOutside),
            replacement: current,
            at: now
        ) == .expectedMealTimeOutOfRange)
        #expect(validationError(
            expected: values(mealTime: futureOutside),
            replacement: current,
            at: now
        ) == .expectedMealTimeOutOfRange)
        #expect(validationError(
            expected: current,
            replacement: values(mealTime: pastOutside),
            at: now
        ) == .replacementMealTimeOutOfRange)
        #expect(validationError(
            expected: current,
            replacement: values(mealTime: futureOutside),
            at: now
        ) == .replacementMealTimeOutOfRange)
    }

    @Test("Retry revalidates while preserving the stored logical mutation")
    @MainActor
    func retryUsesTimePolicyAndPreservesStoredValues() throws {
        let retryDate = now
        let original = operation(
            state: .timedOut,
            expectedMealTime: retryDate.timeIntervalSince1970 - TRCMealMutationTimePolicy.maximumOffset,
            replacementMealTime: retryDate.timeIntervalSince1970 + TRCMealMutationTimePolicy.maximumOffset
        )
        let storage = StorageValue<[TRCMealMutationOperation]>(
            key: "RemoteMealMutationCoordinatorTests-\(UUID().uuidString)",
            defaultValue: [original]
        )
        defer { storage.remove() }

        var sentRequest: TRCMealMutationTransportRequest?
        let coordinator = TRCMealMutationCoordinator(storage: storage) { request, _ in
            sentRequest = request
        }

        let retried = try coordinator.retry(commandID: original.commandID, at: retryDate)
        let request = try #require(sentRequest)

        #expect(retried.state == .sending)
        #expect(retried.commandID == original.commandID)
        #expect(retried.mealID == original.mealID)
        #expect(retried.user == original.user)
        #expect(retried.expected == original.expected)
        #expect(retried.replacement == original.replacement)
        #expect(request.commandID == original.commandID)
        #expect(request.mealID == original.mealID)
        #expect(request.user == original.user)
        #expect(request.expected == original.expected)
        #expect(request.replacement == original.replacement)
        #expect(request.transportTimestamp == retryDate.timeIntervalSince1970)
        #expect(storage.value == [retried])
    }

    @Test("An aged-out retry neither mutates persistence nor sends")
    @MainActor
    func agedOutRetryIsRejectedWithoutSideEffects() {
        let original = operation(
            state: .timedOut,
            expectedMealTime: now.timeIntervalSince1970 - TRCMealMutationTimePolicy.maximumOffset,
            replacementMealTime: now.timeIntervalSince1970
        )
        let storage = StorageValue<[TRCMealMutationOperation]>(
            key: "RemoteMealMutationCoordinatorTests-\(UUID().uuidString)",
            defaultValue: [original]
        )
        defer { storage.remove() }

        var sentRequest: TRCMealMutationTransportRequest?
        let coordinator = TRCMealMutationCoordinator(storage: storage) { request, _ in
            sentRequest = request
        }
        var retryError: TRCMealMutationCoordinatorError?

        do {
            _ = try coordinator.retry(commandID: original.commandID, at: now.addingTimeInterval(0.001))
        } catch let error as TRCMealMutationCoordinatorError {
            retryError = error
        } catch {}

        #expect(retryError == .expectedMealTimeOutOfRange)
        #expect(sentRequest == nil)
        #expect(coordinator.operations == [original])
        #expect(storage.value == [original])
    }

    @Test("Persisted operation round-trips without transport credentials")
    func persistenceRoundTrip() throws {
        let original = operation(state: .inProgress)
        let data = try JSONEncoder().encode(original)
        let json = try #require(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(TRCMealMutationOperation.self, from: data)

        #expect(decoded == original)
        #expect(!json.contains("return_notification"))
        #expect(!json.contains("device_token"))
        #expect(!json.contains("apns_key"))
    }

    @Test("Older generic responses remain unrelated to mutation state")
    func legacyResponseIsIgnored() {
        let response = TRCMealMutationResponse(userInfo: [
            "command_status": "failed",
            "command_type": "edit_meal",
            "timestamp": 1_800_000_005,
            "aps": ["alert": ["body": "Timestamp rejected"]],
        ])

        #expect(response.result == nil)
        #expect(!response.matches(operation(state: .awaiting)))
    }

    private func operation(
        state: TRCMealMutationState,
        expectedMealTime: TimeInterval = 1_799_996_400,
        replacementMealTime: TimeInterval = 1_799_996_700
    ) -> TRCMealMutationOperation {
        TRCMealMutationOperation(
            commandID: commandID,
            mealID: mealID,
            user: "Original User",
            type: .edit,
            expected: TRCMealMutationValues(carbs: 30, fat: 10, protein: 5, mealTime: expectedMealTime),
            replacement: TRCMealMutationValues(carbs: 25, fat: 12, protein: 6, mealTime: replacementMealTime),
            createdAt: now.addingTimeInterval(-120),
            lastAttemptAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60),
            state: state,
            responseBody: state == .inProgress ? "Working" : nil,
            responseResult: state == .inProgress ? .inProgress : nil,
            syncStatus: nil,
            lastResponseTimestamp: state == .inProgress ? 1_800_000_001 : nil,
            reconciledAt: nil
        )
    }

    private func response(
        commandType: String? = "edit_meal",
        commandID: String? = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
        mealID: String? = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB"
    ) -> TRCMealMutationResponse {
        TRCMealMutationResponse(
            commandStatus: "success",
            commandType: commandType,
            commandID: commandID?.lowercased(),
            mealID: mealID?.lowercased(),
            result: .updated,
            syncStatus: .requested,
            timestamp: 1_800_000_005,
            body: "Meal updated"
        )
    }

    private func values(mealTime: TimeInterval) -> TRCMealMutationValues {
        TRCMealMutationValues(carbs: 30, fat: 10, protein: 5, mealTime: mealTime)
    }

    private func validationError(
        expected: TRCMealMutationValues,
        replacement: TRCMealMutationValues,
        at date: Date
    ) -> TRCMealMutationCoordinatorError? {
        do {
            try TRCMealMutationValidator.validate(
                type: .edit,
                expected: expected,
                replacement: replacement,
                at: date
            )
            return nil
        } catch let error as TRCMealMutationCoordinatorError {
            return error
        } catch {
            return nil
        }
    }
}
