// LoopFollow
// StatsDateRange.swift

import Foundation

enum StatsDateRange {
    /// Returns start/end dates for the last complete N-day period.
    /// End is 23:59:59 of yesterday; start is 00:00:00 of the day N days back.
    static func lastComplete(days: Int) -> (start: Date, end: Date) {
        let calendar = dateTimeUtils.displayCalendar()
        let startOfToday = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .second, value: -1, to: startOfToday) ?? Date()
        let endDayStart = calendar.startOfDay(for: end)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: endDayStart) ?? endDayStart
        return (start: calendar.startOfDay(for: start), end: end)
    }
}
