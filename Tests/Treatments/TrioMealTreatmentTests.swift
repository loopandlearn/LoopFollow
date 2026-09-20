// LoopFollow
// TrioMealTreatmentTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TrioMealTreatmentTests {
    private let mealID = "11111111-2222-3333-4444-555555555555"
    private let fpuID = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

    @Test("Nightscout and Trio identities remain distinct and raw meal fields are retained")
    func retainsIdentityMacrosNotesAndPreciseTime() throws {
        let treatment = try #require(TrioMealTreatment(nightscoutEntry: entry(
            nightscoutID: "nightscout-object-id",
            createdAt: "2026-08-16T01:02:03.456+02:30",
            carbs: 0,
            fat: 12,
            protein: 0,
            notes: "Late snack",
            foodType: "Cheese"
        )))

        #expect(treatment.nightscoutID == "nightscout-object-id")
        #expect(treatment.mealID == UUID(uuidString: mealID))
        #expect(treatment.enteredBy == "Trio")
        #expect(treatment.eventType == "Carb Correction")
        #expect(treatment.carbs == 0)
        #expect(treatment.fat == 12)
        #expect(treatment.protein == 0)
        #expect(treatment.notes == "Late snack")
        #expect(treatment.foodType == "Cheese")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let expected = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 15,
            hour: 22,
            minute: 32,
            second: 3,
            nanosecond: 456_000_000
        )))
        #expect(abs(treatment.mealTime - expected.timeIntervalSince1970) < 0.001)
    }

    @Test("Only exact Trio Carb Correction ownership is accepted")
    func requiresExactOwnerAndEventType() {
        var wrongOwner = entry()
        wrongOwner["enteredBy"] = "trio" as AnyObject
        #expect(TrioMealTreatment(nightscoutEntry: wrongOwner) == nil)

        var wrongEvent = entry()
        wrongEvent["eventType"] = "Meal Bolus" as AnyObject
        #expect(TrioMealTreatment(nightscoutEntry: wrongEvent) == nil)
    }

    @Test("Macros must be explicit nonnegative integers with at least one positive value")
    func validatesMacrosLosslessly() throws {
        let fatOnly = try #require(TrioMealTreatment(nightscoutEntry: entry(carbs: 0, fat: 10, protein: 0)))
        #expect(fatOnly.carbs == 0)
        #expect(fatOnly.fat == 10)
        #expect(fatOnly.protein == 0)

        var missingMacro = entry()
        missingMacro.removeValue(forKey: "protein")
        #expect(TrioMealTreatment(nightscoutEntry: missingMacro) == nil)

        var fractionalMacro = entry()
        fractionalMacro["fat"] = NSNumber(value: 1.5)
        #expect(TrioMealTreatment(nightscoutEntry: fractionalMacro) == nil)

        var booleanMacro = entry()
        booleanMacro["carbs"] = true as AnyObject
        #expect(TrioMealTreatment(nightscoutEntry: booleanMacro) == nil)

        #expect(TrioMealTreatment(nightscoutEntry: entry(carbs: 0, fat: 0, protein: 0)) == nil)
        #expect(TrioMealTreatment(nightscoutEntry: entry(carbs: -1, fat: 0, protein: 0)) == nil)
    }

    @Test("Fat/protein-only Trio roots become selectable treatment rows")
    func fatOnlyRootBecomesTreatmentRow() throws {
        let source = entry(carbs: 0, fat: 12, protein: 0)
        let meal = try #require(TrioMealTreatment(nightscoutEntry: source))
        let treatment = try #require(TreatmentsViewModel.makeCarbTreatment(
            from: source,
            trioMeal: meal,
            nightscoutID: meal.nightscoutID,
            timestamp: meal.mealTime,
            actualBG: 123
        ))

        #expect(treatment.id == "nightscout-object-id-carb")
        #expect(treatment.title == "Meal")
        #expect(treatment.subtitle == "12g Fat")
        #expect(treatment.bgValue == 123)
        #expect(treatment.trioMeal == meal)
    }

    @Test("FPU marker contract distinguishes roots, generated children, and ambiguous unmarked roots")
    func classifiesFPURecords() throws {
        let root = try #require(TrioMealTreatment(nightscoutEntry: entry(fpuID: fpuID)))
        #expect(root.fpuClassification == .familyRoot(fpuID: UUID(uuidString: fpuID)!))
        #expect(!root.isGeneratedFPU)
        #expect(!root.hasLegacyFPUAmbiguity)

        let child = try #require(TrioMealTreatment(nightscoutEntry: entry(
            mealID: fpuID.lowercased(),
            fpuID: fpuID
        )))
        #expect(child.fpuClassification == .generatedChild(fpuID: UUID(uuidString: fpuID)!))
        #expect(child.isGeneratedFPU)
        #expect(!child.hasLegacyFPUAmbiguity)

        let unmarked = try #require(TrioMealTreatment(nightscoutEntry: entry()))
        #expect(unmarked.fpuClassification == .unmarkedRoot)
        #expect(!unmarked.isGeneratedFPU)
        #expect(unmarked.hasLegacyFPUAmbiguity)
    }

    @Test("Generated FPU entries resolve only a unique loaded family root")
    func resolvesUniqueLoadedFPURoot() throws {
        let root = try treatment(
            nightscoutID: "root-treatment",
            fpuID: fpuID
        )
        let child = try treatment(
            nightscoutID: "generated-child",
            mealID: fpuID.lowercased(),
            fpuID: fpuID
        )
        let sibling = try treatment(
            nightscoutID: "generated-sibling",
            mealID: fpuID,
            fpuID: fpuID
        )
        let unrelatedRoot = try treatment(
            nightscoutID: "unrelated-root",
            fpuID: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"
        )
        let unmarkedRoot = try treatment(nightscoutID: "unmarked-root")

        let resolved = TreatmentsViewModel.uniqueFPURoot(
            for: child,
            among: [sibling, unrelatedRoot, unmarkedRoot, root]
        )

        #expect(resolved?.id == root.id)
        #expect(TreatmentsViewModel.uniqueFPURoot(
            for: child,
            among: [sibling, unrelatedRoot, unmarkedRoot]
        ) == nil)
        #expect(TreatmentsViewModel.uniqueFPURoot(for: root, among: [root]) == nil)
    }

    @Test("Ambiguous generated FPU roots fail closed")
    func ambiguousFPURootsFailClosed() throws {
        let root = try treatment(
            nightscoutID: "first-root",
            fpuID: fpuID
        )
        let duplicateRoot = try treatment(
            nightscoutID: "second-root",
            mealID: "22222222-3333-4444-5555-666666666666",
            fpuID: fpuID
        )
        let child = try treatment(
            nightscoutID: "generated-child",
            mealID: fpuID,
            fpuID: fpuID
        )

        #expect(TreatmentsViewModel.uniqueFPURoot(
            for: child,
            among: [root, duplicateRoot]
        ) == nil)
    }

    @Test("Mutation eligibility uses the closed symmetric twelve-hour window and excludes generated children")
    func mutationEligibilityBoundaries() throws {
        let root = try #require(TrioMealTreatment(nightscoutEntry: entry()))
        let mealTime = root.mealTime

        #expect(root.isEligibleForMutation(at: Date(timeIntervalSince1970: mealTime)))
        #expect(root.isEligibleForMutation(at: Date(
            timeIntervalSince1970: mealTime + TrioMealTreatment.mutationWindow
        )))
        #expect(root.isEligibleForMutation(at: Date(
            timeIntervalSince1970: mealTime - TrioMealTreatment.mutationWindow
        )))
        #expect(!root.isEligibleForMutation(at: Date(
            timeIntervalSince1970: mealTime + TrioMealTreatment.mutationWindow + 0.001
        )))
        #expect(!root.isEligibleForMutation(at: Date(
            timeIntervalSince1970: mealTime - TrioMealTreatment.mutationWindow - 0.001
        )))

        let child = try #require(TrioMealTreatment(nightscoutEntry: entry(mealID: fpuID, fpuID: fpuID)))
        #expect(!child.isEligibleForMutation(at: Date(timeIntervalSince1970: child.mealTime)))
    }

    @Test("Initial treatment fetch includes the full future mutation window")
    func initialFetchEndMatchesMutationWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(
            TreatmentsViewModel.initialFetchEndDate(at: now).timeIntervalSince(now) ==
                TRCMealMutationTimePolicy.maximumOffset
        )
        #expect(TreatmentsViewModel.includesFutureMutationWindow(remoteType: .trc, device: "Trio"))
        #expect(!TreatmentsViewModel.includesFutureMutationWindow(remoteType: .trc, device: "Loop"))
        #expect(!TreatmentsViewModel.includesFutureMutationWindow(remoteType: .none, device: "Trio"))

        let initialParameters = TreatmentsViewModel.treatmentQueryParameters(
            startDateString: "start",
            endDateString: "end",
            pageSize: 50,
            inclusiveEnd: true
        )
        let paginationParameters = TreatmentsViewModel.treatmentQueryParameters(
            startDateString: "start",
            endDateString: "end",
            pageSize: 50,
            inclusiveEnd: false
        )

        #expect(initialParameters["find[created_at][$lte]"] == "end")
        #expect(initialParameters["find[created_at][$lt]"] == nil)
        #expect(paginationParameters["find[created_at][$lt]"] == "end")
        #expect(paginationParameters["find[created_at][$lte]"] == nil)
    }

    @Test("Refreshed replacement values reconcile an applied edit")
    @MainActor
    func refreshedReplacementReconcilesAppliedEdit() throws {
        let meal = try #require(TrioMealTreatment(nightscoutEntry: entry()))
        let operation = TRCMealMutationOperation(
            commandID: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
            mealID: meal.mealID.uuidString,
            user: "Original User",
            type: .edit,
            expected: TRCMealMutationValues(
                carbs: meal.carbs + 1,
                fat: meal.fat,
                protein: meal.protein,
                mealTime: meal.mealTime - 60
            ),
            replacement: TRCMealMutationValues(
                carbs: meal.carbs,
                fat: meal.fat,
                protein: meal.protein,
                mealTime: meal.mealTime
            ),
            createdAt: Date(timeIntervalSince1970: meal.mealTime - 120),
            lastAttemptAt: Date(timeIntervalSince1970: meal.mealTime - 60),
            updatedAt: Date(timeIntervalSince1970: meal.mealTime - 30),
            state: .applied,
            responseBody: "Updated",
            responseResult: .updated,
            syncStatus: .requested,
            lastResponseTimestamp: meal.mealTime - 30,
            reconciledAt: nil
        )
        let storage = StorageValue<[TRCMealMutationOperation]>(
            key: "TrioMealTreatmentTests-\(UUID().uuidString)",
            defaultValue: [operation]
        )
        defer { storage.remove() }
        let coordinator = TRCMealMutationCoordinator(storage: storage) { _, _ in }
        let treatment = try #require(TreatmentsViewModel.makeCarbTreatment(
            from: entry(),
            trioMeal: meal,
            nightscoutID: meal.nightscoutID,
            timestamp: meal.mealTime,
            actualBG: 100
        ))
        let reconciliationDate = Date(timeIntervalSince1970: meal.mealTime + 1)

        TreatmentsViewModel.reconcileAppliedEdits(
            in: [treatment],
            using: coordinator,
            at: reconciliationDate
        )

        let reconciled = try #require(coordinator.operation(commandID: operation.commandID))
        let staleMeal = try #require(TrioMealTreatment(nightscoutEntry: entry(carbs: meal.carbs + 1)))
        #expect(reconciled.reconciledAt == reconciliationDate)
        #expect(!reconciled.blocksActions)
        #expect(storage.value == [reconciled])
        #expect(TRCMealMutationUIValidation.staleSourceError(meal: staleMeal, after: reconciled) != nil)
        #expect(TRCMealMutationUIValidation.staleSourceError(meal: meal, after: reconciled) == nil)
    }

    @Test("Malformed Trio and FPU UUIDs are rejected")
    func rejectsMalformedUUIDs() {
        #expect(TrioMealTreatment(nightscoutEntry: entry(mealID: "not-a-uuid")) == nil)
        #expect(TrioMealTreatment(nightscoutEntry: entry(fpuID: "not-a-uuid")) == nil)
    }

    private func entry(
        nightscoutID: String = "nightscout-object-id",
        mealID: String? = nil,
        fpuID: String? = nil,
        createdAt: String = "2026-08-16T01:02:03.456Z",
        carbs: Int = 30,
        fat: Int = 10,
        protein: Int = 5,
        notes: String? = nil,
        foodType: String? = nil
    ) -> [String: AnyObject] {
        var result: [String: AnyObject] = [
            "_id": nightscoutID as AnyObject,
            "id": (mealID ?? self.mealID) as AnyObject,
            "enteredBy": "Trio" as AnyObject,
            "eventType": "Carb Correction" as AnyObject,
            "created_at": createdAt as AnyObject,
            "carbs": NSNumber(value: carbs),
            "fat": NSNumber(value: fat),
            "protein": NSNumber(value: protein),
        ]
        if let fpuID {
            result["fpuID"] = fpuID as AnyObject
        }
        if let notes {
            result["notes"] = notes as AnyObject
        }
        if let foodType {
            result["foodType"] = foodType as AnyObject
        }
        return result
    }

    private func treatment(
        nightscoutID: String,
        mealID: String? = nil,
        fpuID: String? = nil
    ) throws -> Treatment {
        let source = entry(
            nightscoutID: nightscoutID,
            mealID: mealID,
            fpuID: fpuID
        )
        let meal = try #require(TrioMealTreatment(nightscoutEntry: source))
        return try #require(TreatmentsViewModel.makeCarbTreatment(
            from: source,
            trioMeal: meal,
            nightscoutID: meal.nightscoutID,
            timestamp: meal.mealTime,
            actualBG: 100
        ))
    }
}
