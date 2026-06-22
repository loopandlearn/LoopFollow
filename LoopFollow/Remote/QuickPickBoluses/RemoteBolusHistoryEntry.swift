// LoopFollow
// RemoteBolusHistoryEntry.swift

import Foundation

/// A record of a remotely-sent bolus, stored locally for pattern-based suggestions.
struct RemoteBolusHistoryEntry: Codable, Equatable {
    /// Bolus amount in international units
    let units: Double

    /// When the bolus was sent
    let date: Date

    /// Day of week: 1=Sunday ... 7=Saturday (Calendar.component(.weekday))
    let dayOfWeek: Int

    /// Minute of day: 0...1439 (hour * 60 + minute)
    let minuteOfDay: Int

    init(units: Double, date: Date) {
        self.units = units
        self.date = date
        let cal = Calendar.current
        dayOfWeek = cal.component(.weekday, from: date)
        minuteOfDay = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }
}
