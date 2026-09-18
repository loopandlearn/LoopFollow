// LoopFollow
// MealMutationCoordinator.swift

import Combine
import Foundation

enum TRCMealMutationType: String, Codable, Equatable, Sendable {
    case edit = "edit_meal"
    case delete = "delete_meal"

    var userFacingName: String {
        switch self {
        case .edit: return "Edit Meal"
        case .delete: return "Delete Meal"
        }
    }
}

struct TRCMealMutationValues: Codable, Equatable, Sendable {
    let carbs: Int
    let fat: Int
    let protein: Int
    let mealTime: TimeInterval

    var hasValidMacros: Bool {
        carbs >= 0 && fat >= 0 && protein >= 0 && (carbs > 0 || fat > 0 || protein > 0)
    }

    var isValid: Bool {
        hasValidMacros && mealTime.isFinite
    }

    func matches(_ other: TRCMealMutationValues, timeTolerance: TimeInterval = 1) -> Bool {
        carbs == other.carbs &&
            fat == other.fat &&
            protein == other.protein &&
            abs(mealTime - other.mealTime) <= timeTolerance
    }
}

struct TRCMealMutationTimePolicy: Sendable {
    static let maximumOffset: TimeInterval = 12 * 60 * 60

    func isValid(_ timestamp: TimeInterval, at date: Date) -> Bool {
        guard timestamp.isFinite else { return false }
        return abs(timestamp - date.timeIntervalSince1970) <= Self.maximumOffset
    }
}

enum TRCMealMutationState: String, Codable, Equatable, Sendable {
    case sending
    case awaiting
    case inProgress
    case applied
    case rejected
    case transportFailed
    case timedOut
}

enum TRCMealMutationResult: String, Codable, Equatable, Sendable {
    case updated
    case deleted
    case alreadyApplied = "already_applied"
    case rejected
    case inProgress = "in_progress"

    var isSuccessful: Bool {
        switch self {
        case .updated, .deleted, .alreadyApplied: return true
        case .rejected, .inProgress: return false
        }
    }
}

enum TRCMealMutationSyncStatus: String, Codable, Equatable, Sendable {
    case requested
    case notRequested = "not_requested"
}

struct TRCMealMutationOperation: Codable, Equatable, Identifiable, Sendable {
    var id: String { commandID }

    let commandID: String
    let mealID: String
    let user: String
    let type: TRCMealMutationType
    let expected: TRCMealMutationValues
    let replacement: TRCMealMutationValues?
    let createdAt: Date

    var lastAttemptAt: Date
    var updatedAt: Date
    var state: TRCMealMutationState
    var responseBody: String?
    var responseResult: TRCMealMutationResult?
    var syncStatus: TRCMealMutationSyncStatus?
    var lastResponseTimestamp: TimeInterval?
    var reconciledAt: Date?

    var isTerminal: Bool {
        state == .applied || state == .rejected
    }

    var isRetryable: Bool {
        switch state {
        case .inProgress, .transportFailed, .timedOut: return true
        case .sending, .awaiting, .applied, .rejected: return false
        }
    }

    /// Applied edits continue to block actions until refreshed Nightscout data
    /// matches the replacement. This prevents a second edit from using a stale
    /// expected-value snapshot while external synchronization catches up.
    var blocksActions: Bool {
        switch state {
        case .sending, .awaiting, .inProgress, .transportFailed, .timedOut:
            return true
        case .applied:
            return reconciledAt == nil
        case .rejected:
            return false
        }
    }

    var statusTitle: String {
        switch state {
        case .sending: return "Sending…"
        case .awaiting: return "Sent — Waiting for Trio"
        case .inProgress: return "Still Processing"
        case .applied:
            switch type {
            case .edit: return "Meal Updated"
            case .delete: return "Meal Deleted"
            }
        case .rejected: return "Rejected by Trio"
        case .transportFailed: return "Couldn’t Send"
        case .timedOut: return "No Response Yet"
        }
    }

    var statusDetail: String {
        if state == .applied {
            var resultText = responseBody ?? "Trio applied the meal change."
            if syncStatus == .requested {
                resultText += " Trio requested external-service synchronization."
            }
            if type == .edit, reconciledAt == nil {
                resultText += " Waiting for refreshed Nightscout values before another change."
            }
            return resultText
        }

        if let responseBody, !responseBody.isEmpty {
            return responseBody
        }

        switch state {
        case .sending: return "Encrypting and sending the command to APNs."
        case .awaiting: return "APNs accepted the command. Waiting for Trio to report the result."
        case .inProgress: return "Trio has not finished processing this request. Retry the same request shortly."
        case .rejected: return "Trio did not apply the meal change."
        case .transportFailed: return "LoopFollow could not confirm that APNs accepted the command. Retry the same request."
        case .timedOut: return "No correlated Trio response has arrived. Retry the same request."
        case .applied: return "Trio applied the meal change."
        }
    }

    func transportRequest(at date: Date) -> TRCMealMutationTransportRequest {
        TRCMealMutationTransportRequest(
            commandID: commandID,
            mealID: mealID,
            user: user,
            type: type,
            expected: expected,
            replacement: replacement,
            transportTimestamp: date.timeIntervalSince1970
        )
    }
}

/// Ephemeral send data. Return-notification credentials are deliberately absent;
/// the live transport recreates them for every initial attempt and retry.
struct TRCMealMutationTransportRequest: Equatable, Sendable {
    let commandID: String
    let mealID: String
    let user: String
    let type: TRCMealMutationType
    let expected: TRCMealMutationValues
    let replacement: TRCMealMutationValues?
    let transportTimestamp: TimeInterval
}

struct TRCMealMutationResponse: Equatable, Sendable {
    let commandStatus: String?
    let commandType: String?
    let commandID: String?
    let mealID: String?
    let result: TRCMealMutationResult?
    let syncStatus: TRCMealMutationSyncStatus?
    let timestamp: TimeInterval?
    let body: String?

    init(
        commandStatus: String? = nil,
        commandType: String? = nil,
        commandID: String? = nil,
        mealID: String? = nil,
        result: TRCMealMutationResult? = nil,
        syncStatus: TRCMealMutationSyncStatus? = nil,
        timestamp: TimeInterval? = nil,
        body: String? = nil
    ) {
        self.commandStatus = commandStatus
        self.commandType = commandType
        self.commandID = commandID
        self.mealID = mealID
        self.result = result
        self.syncStatus = syncStatus
        self.timestamp = timestamp
        self.body = body
    }

    init(userInfo: [AnyHashable: Any]) {
        commandStatus = userInfo["command_status"] as? String
        commandType = userInfo["command_type"] as? String
        commandID = userInfo["command_id"] as? String
        mealID = userInfo["meal_id"] as? String
        result = (userInfo["result"] as? String).flatMap(TRCMealMutationResult.init(rawValue:))
        syncStatus = (userInfo["sync_status"] as? String).flatMap(TRCMealMutationSyncStatus.init(rawValue:))
        timestamp = Self.timeInterval(from: userInfo["timestamp"])

        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any]
        {
            body = alert["body"] as? String
        } else {
            body = nil
        }
    }

    func matches(_ operation: TRCMealMutationOperation) -> Bool {
        guard commandType == operation.type.rawValue,
              let canonicalCommandID = Self.canonicalUUID(commandID),
              let canonicalMealID = Self.canonicalUUID(mealID)
        else {
            return false
        }

        return canonicalCommandID == operation.commandID && canonicalMealID == operation.mealID
    }

    static func canonicalUUID(_ value: String?) -> String? {
        guard let value, let uuid = UUID(uuidString: value) else { return nil }
        return uuid.uuidString
    }

    private static func timeInterval(from value: Any?) -> TimeInterval? {
        switch value {
        case let value as TimeInterval:
            return value.isFinite ? value : nil
        case let value as NSNumber:
            let result = value.doubleValue
            return result.isFinite ? result : nil
        default:
            return nil
        }
    }
}

enum TRCMealMutationEvent: Equatable, Sendable {
    case retryStarted
    case transportAccepted
    case transportFailed(String?)
    case timedOut
    case response(
        result: TRCMealMutationResult,
        syncStatus: TRCMealMutationSyncStatus?,
        body: String?,
        timestamp: TimeInterval?
    )
    case reconciled
}

enum TRCMealMutationReducer {
    static func reduce(
        _ operation: TRCMealMutationOperation,
        event: TRCMealMutationEvent,
        at date: Date
    ) -> TRCMealMutationOperation {
        var updated = operation

        if operation.isTerminal {
            if case .reconciled = event, operation.state == .applied, operation.reconciledAt == nil {
                updated.reconciledAt = date
                updated.updatedAt = date
            }
            return updated
        }

        switch event {
        case .retryStarted:
            updated.state = .sending
            updated.lastAttemptAt = date
            updated.updatedAt = date
            updated.responseBody = nil

        case .transportAccepted:
            guard operation.state == .sending else { return operation }
            updated.state = .awaiting
            updated.updatedAt = date
            updated.responseBody = nil

        case let .transportFailed(message):
            guard operation.state == .sending else { return operation }
            updated.state = .transportFailed
            updated.updatedAt = date
            updated.responseBody = message

        case .timedOut:
            guard operation.state == .sending || operation.state == .awaiting || operation.state == .inProgress else {
                return operation
            }
            updated.state = .timedOut
            updated.updatedAt = date

        case let .response(result, syncStatus, body, timestamp):
            if timestamp == operation.lastResponseTimestamp,
               result == operation.responseResult,
               syncStatus == operation.syncStatus
            {
                return operation
            }

            if let timestamp,
               let lastTimestamp = operation.lastResponseTimestamp,
               timestamp < lastTimestamp
            {
                return operation
            }

            updated.updatedAt = date
            updated.responseBody = body
            updated.responseResult = result
            updated.syncStatus = syncStatus
            if let timestamp {
                updated.lastResponseTimestamp = timestamp
            }

            switch result {
            case .updated, .deleted, .alreadyApplied:
                updated.state = .applied
            case .rejected:
                updated.state = .rejected
            case .inProgress:
                updated.state = .inProgress
            }

        case .reconciled:
            return operation
        }

        return updated
    }
}

enum TRCMealMutationValidator {
    static func validate(
        type: TRCMealMutationType,
        expected: TRCMealMutationValues,
        replacement: TRCMealMutationValues?,
        at date: Date
    ) throws {
        let timePolicy = TRCMealMutationTimePolicy()
        guard expected.isValid else {
            throw TRCMealMutationCoordinatorError.invalidExpectedValues
        }
        guard timePolicy.isValid(expected.mealTime, at: date) else {
            throw TRCMealMutationCoordinatorError.expectedMealTimeOutOfRange
        }

        switch type {
        case .edit:
            guard let replacement, replacement.isValid else {
                throw TRCMealMutationCoordinatorError.invalidReplacementValues
            }
            guard timePolicy.isValid(replacement.mealTime, at: date) else {
                throw TRCMealMutationCoordinatorError.replacementMealTimeOutOfRange
            }
        case .delete:
            guard replacement == nil else {
                throw TRCMealMutationCoordinatorError.unexpectedReplacementValues
            }
        }
    }
}

enum TRCMealMutationCoordinatorError: LocalizedError, Equatable {
    case invalidCommandID
    case invalidMealID
    case missingUser
    case invalidExpectedValues
    case expectedMealTimeOutOfRange
    case invalidReplacementValues
    case replacementMealTimeOutOfRange
    case unexpectedReplacementValues
    case operationAlreadyExists
    case operationAlreadyPending
    case operationNotFound
    case operationIsTerminal
    case operationNotRetryable

    var errorDescription: String? {
        switch self {
        case .invalidCommandID: return "The meal command ID is invalid."
        case .invalidMealID: return "The Trio meal ID is invalid."
        case .missingUser: return "The configured remote-command user is missing."
        case .invalidExpectedValues: return "The loaded meal values are incomplete or invalid."
        case .expectedMealTimeOutOfRange: return "The source meal time must be within 12 hours of now."
        case .invalidReplacementValues: return "The replacement meal values are incomplete or invalid."
        case .replacementMealTimeOutOfRange: return "The replacement meal time must be within 12 hours of now."
        case .unexpectedReplacementValues: return "A delete request cannot include replacement meal values."
        case .operationAlreadyExists: return "That meal command ID has already been used."
        case .operationAlreadyPending: return "A meal change for this meal is already pending."
        case .operationNotFound: return "The pending meal change was not found."
        case .operationIsTerminal: return "A completed meal change cannot be retried."
        case .operationNotRetryable: return "This meal change is still awaiting a result and cannot be retried yet."
        }
    }
}

@MainActor
final class TRCMealMutationCoordinator: ObservableObject {
    static let attemptTimeout: TimeInterval = 60

    typealias Transport = (
        TRCMealMutationTransportRequest,
        @escaping (_ acceptedByAPNs: Bool, _ errorMessage: String?) -> Void
    ) -> Void

    static let shared = TRCMealMutationCoordinator(
        storage: Storage.shared.pendingTRCMealMutations,
        transport: liveTransport
    )

    @Published private(set) var operations: [TRCMealMutationOperation]

    private let storage: StorageValue<[TRCMealMutationOperation]>
    private let transport: Transport

    init(
        storage: StorageValue<[TRCMealMutationOperation]>,
        transport: @escaping Transport,
        at date: Date = Date()
    ) {
        self.storage = storage
        self.transport = transport
        operations = storage.value
        recoverExpiredAttempts(at: date)
    }

    @discardableResult
    func startEdit(
        mealID: String,
        user: String,
        expectedCarbs: Int,
        expectedFat: Int,
        expectedProtein: Int,
        expectedMealTime: TimeInterval,
        carbs: Int,
        fat: Int,
        protein: Int,
        scheduledTime: TimeInterval,
        commandID: UUID = UUID(),
        at date: Date = Date()
    ) throws -> TRCMealMutationOperation {
        let expected = TRCMealMutationValues(
            carbs: expectedCarbs,
            fat: expectedFat,
            protein: expectedProtein,
            mealTime: expectedMealTime
        )
        let replacement = TRCMealMutationValues(
            carbs: carbs,
            fat: fat,
            protein: protein,
            mealTime: scheduledTime
        )
        return try start(
            type: .edit,
            mealID: mealID,
            user: user,
            expected: expected,
            replacement: replacement,
            commandID: commandID,
            at: date
        )
    }

    @discardableResult
    func startDelete(
        mealID: String,
        user: String,
        expectedCarbs: Int,
        expectedFat: Int,
        expectedProtein: Int,
        expectedMealTime: TimeInterval,
        commandID: UUID = UUID(),
        at date: Date = Date()
    ) throws -> TRCMealMutationOperation {
        let expected = TRCMealMutationValues(
            carbs: expectedCarbs,
            fat: expectedFat,
            protein: expectedProtein,
            mealTime: expectedMealTime
        )
        return try start(
            type: .delete,
            mealID: mealID,
            user: user,
            expected: expected,
            replacement: nil,
            commandID: commandID,
            at: date
        )
    }

    @discardableResult
    func retry(commandID: String, at date: Date = Date()) throws -> TRCMealMutationOperation {
        guard let canonicalCommandID = TRCMealMutationResponse.canonicalUUID(commandID),
              let index = operations.firstIndex(where: { $0.commandID == canonicalCommandID })
        else {
            throw TRCMealMutationCoordinatorError.operationNotFound
        }
        guard !operations[index].isTerminal else {
            throw TRCMealMutationCoordinatorError.operationIsTerminal
        }
        guard operations[index].isRetryable else {
            throw TRCMealMutationCoordinatorError.operationNotRetryable
        }
        try TRCMealMutationValidator.validate(
            type: operations[index].type,
            expected: operations[index].expected,
            replacement: operations[index].replacement,
            at: date
        )

        let updated = TRCMealMutationReducer.reduce(operations[index], event: .retryStarted, at: date)
        replaceOperation(at: index, with: updated)
        send(updated.transportRequest(at: date))
        return operations[index]
    }

    func operation(forMealID mealID: String) -> TRCMealMutationOperation? {
        guard let canonicalMealID = TRCMealMutationResponse.canonicalUUID(mealID) else { return nil }
        return operations
            .filter { $0.mealID == canonicalMealID }
            .max { $0.createdAt < $1.createdAt }
    }

    func operation(commandID: String) -> TRCMealMutationOperation? {
        guard let canonicalCommandID = TRCMealMutationResponse.canonicalUUID(commandID) else { return nil }
        return operations.first { $0.commandID == canonicalCommandID }
    }

    func blockingOperation(forMealID mealID: String) -> TRCMealMutationOperation? {
        guard let canonicalMealID = TRCMealMutationResponse.canonicalUUID(mealID) else { return nil }
        return operations
            .filter { $0.mealID == canonicalMealID && $0.blocksActions }
            .max { $0.createdAt < $1.createdAt }
    }

    func markTimedOut(commandID: String, at date: Date = Date()) {
        apply(event: .timedOut, toCommandID: commandID, at: date)
    }

    func recoverExpiredAttempts(at date: Date = Date()) {
        var recovered = operations
        for index in recovered.indices {
            let operation = recovered[index]
            guard operation.state == .sending || operation.state == .awaiting,
                  date.timeIntervalSince(operation.lastAttemptAt) >= Self.attemptTimeout
            else {
                continue
            }
            recovered[index] = TRCMealMutationReducer.reduce(operation, event: .timedOut, at: date)
        }

        guard recovered != operations else { return }
        operations = recovered
        storage.value = recovered
    }

    /// Marks an applied edit reconciled only after freshly loaded Nightscout
    /// values match the requested replacement. Returns true when it changed state.
    @discardableResult
    func reconcileAppliedEdit(
        mealID: String,
        carbs: Int,
        fat: Int,
        protein: Int,
        mealTime: TimeInterval,
        at date: Date = Date()
    ) -> Bool {
        guard let canonicalMealID = TRCMealMutationResponse.canonicalUUID(mealID) else { return false }
        let observed = TRCMealMutationValues(carbs: carbs, fat: fat, protein: protein, mealTime: mealTime)
        guard let index = operations.indices
            .filter({
                let operation = operations[$0]
                return operation.mealID == canonicalMealID &&
                    operation.type == .edit &&
                    operation.state == .applied &&
                    operation.reconciledAt == nil &&
                    operation.replacement?.matches(observed) == true
            })
            .max(by: { operations[$0].createdAt < operations[$1].createdAt })
        else {
            return false
        }

        let previous = operations[index]
        let updated = TRCMealMutationReducer.reduce(previous, event: .reconciled, at: date)
        guard updated != previous else { return false }
        replaceOperation(at: index, with: updated)
        return true
    }

    @discardableResult
    func handleRemoteNotification(userInfo: [AnyHashable: Any], at date: Date = Date()) -> Bool {
        let response = TRCMealMutationResponse(userInfo: userInfo)
        guard let result = response.result,
              let canonicalCommandID = TRCMealMutationResponse.canonicalUUID(response.commandID),
              let index = operations.firstIndex(where: { $0.commandID == canonicalCommandID }),
              response.matches(operations[index])
        else {
            return false
        }

        let previous = operations[index]
        let updated = TRCMealMutationReducer.reduce(
            previous,
            event: .response(
                result: result,
                syncStatus: response.syncStatus,
                body: response.body,
                timestamp: response.timestamp
            ),
            at: date
        )

        if updated != previous {
            replaceOperation(at: index, with: updated)
        }

        if !previous.isTerminal, updated.isTerminal {
            NotificationCenter.default.post(
                name: .trcMealMutationDidComplete,
                object: nil,
                userInfo: [
                    "command_id": updated.commandID,
                    "meal_id": updated.mealID,
                    "command_type": updated.type.rawValue,
                ]
            )
        }

        return true
    }

    private func start(
        type: TRCMealMutationType,
        mealID: String,
        user: String,
        expected: TRCMealMutationValues,
        replacement: TRCMealMutationValues?,
        commandID: UUID,
        at date: Date
    ) throws -> TRCMealMutationOperation {
        let canonicalCommandID = commandID.uuidString
        guard let canonicalMealID = TRCMealMutationResponse.canonicalUUID(mealID) else {
            throw TRCMealMutationCoordinatorError.invalidMealID
        }
        guard !user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TRCMealMutationCoordinatorError.missingUser
        }
        try TRCMealMutationValidator.validate(
            type: type,
            expected: expected,
            replacement: replacement,
            at: date
        )
        guard !operations.contains(where: { $0.commandID == canonicalCommandID }) else {
            throw TRCMealMutationCoordinatorError.operationAlreadyExists
        }
        guard blockingOperation(forMealID: canonicalMealID) == nil else {
            throw TRCMealMutationCoordinatorError.operationAlreadyPending
        }

        let operation = TRCMealMutationOperation(
            commandID: canonicalCommandID,
            mealID: canonicalMealID,
            user: user,
            type: type,
            expected: expected,
            replacement: replacement,
            createdAt: date,
            lastAttemptAt: date,
            updatedAt: date,
            state: .sending,
            responseBody: nil,
            responseResult: nil,
            syncStatus: nil,
            lastResponseTimestamp: nil,
            reconciledAt: nil
        )

        appendAndPersist(operation)
        send(operation.transportRequest(at: date))
        return self.operation(commandID: canonicalCommandID) ?? operation
    }

    private func send(_ request: TRCMealMutationTransportRequest) {
        transport(request) { [weak self] accepted, message in
            guard let self else { return }
            if accepted {
                self.apply(
                    event: .transportAccepted,
                    toCommandID: request.commandID,
                    attemptTimestamp: request.transportTimestamp,
                    at: Date()
                )
            } else {
                self.apply(
                    event: .transportFailed(message),
                    toCommandID: request.commandID,
                    attemptTimestamp: request.transportTimestamp,
                    at: Date()
                )
            }
        }
    }

    private func apply(
        event: TRCMealMutationEvent,
        toCommandID commandID: String,
        attemptTimestamp: TimeInterval? = nil,
        at date: Date
    ) {
        guard let canonicalCommandID = TRCMealMutationResponse.canonicalUUID(commandID),
              let index = operations.firstIndex(where: { $0.commandID == canonicalCommandID })
        else {
            return
        }
        if let attemptTimestamp,
           operations[index].lastAttemptAt.timeIntervalSince1970 != attemptTimestamp
        {
            return
        }

        let updated = TRCMealMutationReducer.reduce(operations[index], event: event, at: date)
        guard updated != operations[index] else { return }
        replaceOperation(at: index, with: updated)
    }

    private func appendAndPersist(_ operation: TRCMealMutationOperation) {
        operations.append(operation)
        storage.value = operations
    }

    private func replaceOperation(at index: Int, with operation: TRCMealMutationOperation) {
        operations[index] = operation
        storage.value = operations
    }

    private static func liveTransport(
        _ request: TRCMealMutationTransportRequest,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let commandID = UUID(uuidString: request.commandID) else {
            completion(false, TRCMealMutationCoordinatorError.invalidCommandID.localizedDescription)
            return
        }
        guard let mealID = UUID(uuidString: request.mealID) else {
            completion(false, TRCMealMutationCoordinatorError.invalidMealID.localizedDescription)
            return
        }

        let manager = PushNotificationManager()
        do {
            let returnNotification = try manager.requireReturnNotificationInfo()
            let payload: CommandPayload
            switch request.type {
            case .edit:
                guard let replacement = request.replacement else {
                    completion(false, TRCMealMutationCoordinatorError.invalidReplacementValues.localizedDescription)
                    return
                }
                payload = .editMeal(
                    user: request.user,
                    timestamp: request.transportTimestamp,
                    commandID: commandID,
                    mealID: mealID,
                    expectedCarbs: request.expected.carbs,
                    expectedFat: request.expected.fat,
                    expectedProtein: request.expected.protein,
                    expectedMealTime: request.expected.mealTime,
                    carbs: replacement.carbs,
                    fat: replacement.fat,
                    protein: replacement.protein,
                    scheduledTime: replacement.mealTime,
                    returnNotification: returnNotification
                )
            case .delete:
                payload = .deleteMeal(
                    user: request.user,
                    timestamp: request.transportTimestamp,
                    commandID: commandID,
                    mealID: mealID,
                    expectedCarbs: request.expected.carbs,
                    expectedFat: request.expected.fat,
                    expectedProtein: request.expected.protein,
                    expectedMealTime: request.expected.mealTime,
                    returnNotification: returnNotification
                )
            }

            manager.sendPreparedMealMutationPayload(payload) { accepted, message in
                DispatchQueue.main.async {
                    completion(accepted, message)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
}

extension Notification.Name {
    static let trcMealMutationDidComplete = Notification.Name("LoopFollow.trcMealMutationDidComplete")
}
