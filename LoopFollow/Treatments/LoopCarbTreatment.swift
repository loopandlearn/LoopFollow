// LoopFollow
// LoopCarbTreatment.swift

import Foundation

/// Loop carb entry metadata from a Nightscout "Carb Correction" treatment.
///
/// `syncIdentifier` is Loop's stable handle for the entry; it survives edits on the phone,
/// so it addresses the entry in remote delete/edit commands.
struct LoopCarbTreatment: Equatable {
    static let editWindow: TimeInterval = 23 * 3600

    let nightscoutID: String
    let syncIdentifier: String
    let enteredBy: String
    let date: TimeInterval
    let carbs: Double
    let absorptionMinutes: Double?
    let foodType: String?

    init?(nightscoutEntry entry: [String: AnyObject], date: TimeInterval) {
        guard let enteredBy = entry["enteredBy"] as? String,
              enteredBy.hasPrefix("loop://"),
              entry["eventType"] as? String == "Carb Correction",
              let syncIdentifier = entry["syncIdentifier"] as? String,
              !syncIdentifier.isEmpty,
              let carbs = (entry["carbs"] as? NSNumber)?.doubleValue,
              carbs > 0
        else {
            return nil
        }

        nightscoutID = entry["_id"] as? String ?? ""
        self.syncIdentifier = syncIdentifier
        self.enteredBy = enteredBy
        self.date = date
        self.carbs = carbs
        absorptionMinutes = (entry["absorptionTime"] as? NSNumber)?.doubleValue
        let rawFoodType = (entry["foodType"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        foodType = rawFoodType?.isEmpty == false ? rawFoodType : nil
    }

    var absorptionHours: Double? {
        absorptionMinutes.map { $0 / 60 }
    }

    func isWithinEditWindow(now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince1970 - date
        return age <= Self.editWindow && age >= -3600
    }

    static func remoteActionsAvailable(remoteType: RemoteType, device: String) -> Bool {
        remoteType == .loopAPNS && device == "Loop"
    }
}
