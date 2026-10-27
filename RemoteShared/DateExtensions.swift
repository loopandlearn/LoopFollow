// LoopFollow
// DateExtensions.swift

import Foundation

// MARK: - Date Extension for NS Compatibility

extension Date {
    /// Creates a new date with the original date's components but current seconds and milliseconds
    /// This prevents Nightscout issues with entries at the same exact time
    /// - Returns: A new date with randomized milliseconds
    func dateUsingCurrentSeconds() -> Date {
        let calendar = Calendar.current

        // Extracting components from the original date
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)

        // Getting the current seconds and milliseconds
        let now = Date()
        let nowSeconds = calendar.component(.second, from: now)
        let nowMillisecond = calendar.component(.nanosecond, from: now) / 1_000_000

        // Setting the seconds and millisecond components
        components.second = nowSeconds
        components.nanosecond = nowMillisecond * 1_000_000

        // Creating a new date with these components
        return calendar.date(from: components) ?? self
    }
}
