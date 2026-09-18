// LoopFollow
// TrioMealTreatment.swift

import CoreFoundation
import Foundation

/// Mutation-safe metadata retained from a Trio Nightscout meal treatment.
///
/// Nightscout's `_id` remains the treatment's display/deduplication identity,
/// while `mealID` is Trio's stable Core Data UUID used by remote meal commands.
struct TrioMealTreatment: Equatable, Sendable {
    static let mutationWindow = TRCMealMutationTimePolicy.maximumOffset

    enum FPUClassification: Equatable, Sendable {
        /// A root with a generated FPU family. Its meal and family IDs differ.
        case familyRoot(fpuID: UUID)

        /// A generated FPU child. Trio publishes its family ID as both fields.
        case generatedChild(fpuID: UUID)

        /// A root under the current marker contract. Legacy records without the
        /// marker remain structurally ambiguous, so callers may gate this case.
        case unmarkedRoot

        var isRootUnderCurrentContract: Bool {
            switch self {
            case .familyRoot, .unmarkedRoot:
                return true
            case .generatedChild:
                return false
            }
        }

        var hasLegacyAmbiguity: Bool {
            self == .unmarkedRoot
        }

        var fpuID: UUID? {
            switch self {
            case let .familyRoot(fpuID), let .generatedChild(fpuID):
                return fpuID
            case .unmarkedRoot:
                return nil
            }
        }
    }

    let nightscoutID: String
    let mealID: UUID
    let enteredBy: String
    let eventType: String
    let mealTime: TimeInterval
    let carbs: Int
    let fat: Int
    let protein: Int
    let notes: String?
    let foodType: String?
    let fpuClassification: FPUClassification

    var fpuID: UUID? {
        fpuClassification.fpuID
    }

    var isGeneratedFPU: Bool {
        if case .generatedChild = fpuClassification {
            return true
        }
        return false
    }

    var hasLegacyFPUAmbiguity: Bool {
        fpuClassification.hasLegacyAmbiguity
    }

    init?(nightscoutEntry entry: [String: AnyObject]) {
        guard let enteredBy = entry["enteredBy"] as? String,
              enteredBy == "Trio",
              let eventType = entry["eventType"] as? String,
              eventType == "Carb Correction",
              let nightscoutID = entry["_id"] as? String,
              !nightscoutID.isEmpty,
              let rawMealID = entry["id"] as? String,
              let mealID = UUID(uuidString: rawMealID),
              let mealTime = Self.preciseTimestamp(from: entry["created_at"]),
              let carbs = Self.exactInteger(from: entry["carbs"]),
              let fat = Self.exactInteger(from: entry["fat"]),
              let protein = Self.exactInteger(from: entry["protein"]),
              carbs >= 0,
              fat >= 0,
              protein >= 0,
              carbs > 0 || fat > 0 || protein > 0
        else {
            return nil
        }

        let fpuClassification: FPUClassification
        if let rawFPUIDValue = entry["fpuID"], !(rawFPUIDValue is NSNull) {
            guard let rawFPUID = rawFPUIDValue as? String,
                  let fpuID = UUID(uuidString: rawFPUID)
            else {
                return nil
            }
            fpuClassification = mealID == fpuID ? .generatedChild(fpuID: fpuID) : .familyRoot(fpuID: fpuID)
        } else {
            fpuClassification = .unmarkedRoot
        }

        self.nightscoutID = nightscoutID
        self.mealID = mealID
        self.enteredBy = enteredBy
        self.eventType = eventType
        self.mealTime = mealTime
        self.carbs = carbs
        self.fat = fat
        self.protein = protein
        notes = entry["notes"] as? String
        foodType = entry["foodType"] as? String
        self.fpuClassification = fpuClassification
    }

    func isWithinMutationWindow(at now: Date) -> Bool {
        TRCMealMutationTimePolicy().isValid(mealTime, at: now)
    }

    func isEligibleForMutation(at now: Date) -> Bool {
        fpuClassification.isRootUnderCurrentContract && isWithinMutationWindow(at: now)
    }

    private static func preciseTimestamp(from value: AnyObject?) -> TimeInterval? {
        guard let rawTimestamp = value as? String else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: rawTimestamp) {
            return date.timeIntervalSince1970
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawTimestamp)?.timeIntervalSince1970
    }

    private static func exactInteger(from value: AnyObject?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              !number.decimalValue.isNaN
        else {
            return nil
        }

        let integer = number.int64Value
        guard number.decimalValue == Decimal(integer) else { return nil }
        return Int(exactly: integer)
    }
}
