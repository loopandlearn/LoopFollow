// LoopFollow
// TrioMealTreatment.swift

import Foundation

/// Trio meal metadata from a Nightscout "Carb Correction" treatment.
///
/// Nightscout's `_id` identifies the document; `id` is Trio's meal UUID. FPU children are
/// separate documents whose `id` equals the root's `fpuID`, so either value works as a handle
/// for Trio's remote edit/delete commands.
struct TrioMealTreatment: Equatable {
    static let pastEditWindow: TimeInterval = 24 * 3600
    static let futureEditWindow: TimeInterval = 12 * 3600
    static let requiredRemoteCommands: Set<String> = [TRCCommandType.editMeal.rawValue, TRCCommandType.deleteMeal.rawValue]

    let nightscoutID: String
    let mealID: UUID
    let fpuID: UUID?
    let date: TimeInterval
    let carbs: Double
    let fat: Int
    let protein: Int
    let note: String?
    let isFPUChild: Bool

    /// `siblingIDCount` is how many Trio carb documents in the same page share this `id`.
    /// Builds without `fpuID` in the upload are classified by that count: children share an id, roots are unique.
    init?(nightscoutEntry entry: [String: AnyObject], date: TimeInterval, siblingIDCount: Int) {
        guard entry["enteredBy"] as? String == "Trio",
              entry["eventType"] as? String == "Carb Correction",
              let rawID = entry["id"] as? String,
              let mealID = UUID(uuidString: rawID)
        else {
            return nil
        }

        let carbs = Self.number(entry["carbs"]) ?? 0
        let fat = Int((Self.number(entry["fat"]) ?? 0).rounded())
        let protein = Int((Self.number(entry["protein"]) ?? 0).rounded())
        guard carbs > 0 || fat > 0 || protein > 0 else { return nil }

        let fpuID = (entry["fpuID"] as? String).flatMap(UUID.init(uuidString:))
        let isFPUChild: Bool
        if let fpuID {
            isFPUChild = fpuID == mealID
        } else {
            isFPUChild = siblingIDCount > 1
        }

        let rawNote = (entry["notes"] as? String) ?? (entry["foodType"] as? String)
        let trimmedNote = rawNote?.trimmingCharacters(in: .whitespacesAndNewlines)

        nightscoutID = entry["_id"] as? String ?? ""
        self.mealID = mealID
        self.fpuID = fpuID
        self.date = date
        self.carbs = carbs
        self.fat = fat
        self.protein = protein
        note = trimmedNote?.isEmpty == false ? trimmedNote : nil
        self.isFPUChild = isFPUChild
    }

    var carbsForEdit: Int { Int(carbs.rounded()) }

    func isWithinEditWindow(now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince1970 - date
        return age <= Self.pastEditWindow && age >= -Self.futureEditWindow
    }

    static func siblingIDCounts(in entries: [[String: AnyObject]]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            guard entry["enteredBy"] as? String == "Trio",
                  entry["eventType"] as? String == "Carb Correction",
                  let id = entry["id"] as? String
            else { continue }
            counts[id, default: 0] += 1
        }
        return counts
    }

    /// Remote edit/delete is offered only when Trio Remote Control targets a Trio that lists both commands.
    static func remoteActionsAvailable(remoteType: RemoteType, device: String, remoteCommands: [String]) -> Bool {
        remoteType == .trc && device == "Trio" && requiredRemoteCommands.isSubset(of: remoteCommands)
    }

    private static func number(_ value: AnyObject?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
