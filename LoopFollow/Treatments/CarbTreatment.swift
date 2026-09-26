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
            return Treatment(
                id: "\(carb.nightscoutID)-carb",
                type: .carb,
                date: carb.date,
                title: "\(Int(carb.carbs))g",
                subtitle: "Carbs",
                icon: "circle.fill",
                color: .orange,
                bgValue: 0,
                loopCarb: carb
            )
        case let .trio(meal):
            let macros = [
                meal.fat > 0 ? "\(meal.fat) g fat" : nil,
                meal.protein > 0 ? "\(meal.protein) g protein" : nil,
            ].compactMap { $0 }.joined(separator: " • ")
            return Treatment(
                id: "\(meal.nightscoutID)-carb",
                type: .carb,
                date: meal.date,
                title: meal.carbs > 0 ? "\(Int(meal.carbs))g" : "Meal",
                subtitle: meal.isFPUChild ? "Carbs • FPU" : (meal.carbs > 0 ? "Carbs" : macros),
                icon: "circle.fill",
                color: .orange,
                bgValue: 0,
                trioMeal: meal
            )
        }
    }
}
