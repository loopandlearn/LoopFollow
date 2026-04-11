// LoopFollow
// RemoteMealHistoryEntry.swift

import Foundation

/// A record of a remotely-sent meal, stored locally for pattern-based common meals.
struct RemoteMealHistoryEntry: Codable, Equatable {
    /// Carbs in grams
    let carbs: Double

    /// Fat in grams (0 if not applicable)
    let fat: Double

    /// Protein in grams (0 if not applicable)
    let protein: Double

    /// Bolus in units (0 if no bolus with meal)
    let bolus: Double

    /// When the meal was sent
    let date: Date

    /// Day of week: 1=Sunday ... 7=Saturday (Calendar.component(.weekday))
    let dayOfWeek: Int

    /// Minute of day: 0...1439 (hour * 60 + minute)
    let minuteOfDay: Int

    init(carbs: Double, fat: Double = 0, protein: Double = 0, bolus: Double = 0, date: Date = Date()) {
        self.carbs = carbs
        self.fat = fat
        self.protein = protein
        self.bolus = bolus
        self.date = date
        let cal = Calendar.current
        dayOfWeek = cal.component(.weekday, from: date)
        minuteOfDay = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }
}
