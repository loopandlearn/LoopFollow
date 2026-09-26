// LoopFollow
// CarbTreatment.swift

import Foundation

/// Source metadata for a carb mark, preserving the identifier used by its AID app.
enum CarbTreatment: Codable, Equatable {
    case loop(LoopCarbTreatment)
    case trio(TrioMealTreatment)

    init?(nightscoutEntry entry: [String: AnyObject], date: TimeInterval) {
        if let meal = TrioMealTreatment(nightscoutEntry: entry, date: date) {
            self = .trio(meal)
        } else if let carb = LoopCarbTreatment(nightscoutEntry: entry, date: date) {
            self = .loop(carb)
        } else {
            return nil
        }
    }

    /// The existing detail screen owns all remote action availability and command handling.
    var detailTreatment: Treatment {
        switch self {
        case let .loop(carb):
            return .carb(nightscoutID: carb.nightscoutID, date: carb.date, carbs: carb.carbs, bgValue: 0, loopCarb: carb)
        case let .trio(meal):
            return .carb(nightscoutID: meal.nightscoutID, date: meal.date, carbs: meal.carbs, bgValue: 0, trioMeal: meal)
        }
    }
}
