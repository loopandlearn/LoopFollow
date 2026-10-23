// LoopFollow
// SpokenDuration.swift

import Foundation

/// English phrases for durations and clock times, written for Siri dialogs.
enum SpokenDuration {
    private static let components: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        return formatter
    }()

    /// "1 hour, 30 minutes". Seconds are truncated to whole minutes; under a minute
    /// reads "less than a minute".
    static func duration(_ seconds: TimeInterval) -> String {
        let wholeMinutes = (max(seconds, 0) / 60).rounded(.down) * 60
        guard wholeMinutes >= 60 else { return "less than a minute" }
        return components.string(from: wholeMinutes) ?? "\(Int(wholeMinutes / 60)) minutes"
    }

    /// "3 minutes ago"; under a minute reads "just now".
    static func ago(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "just now" }
        return "\(duration(seconds)) ago"
    }

    /// Age of an insertion timestamp (epoch seconds) relative to `now`.
    static func age(since insertTime: TimeInterval, now: Date) -> String {
        duration(now.timeIntervalSince1970 - insertTime)
    }

    /// Clock time in the device's 12/24-hour style, e.g. "2:30 PM" or "14:30".
    static func clockTime(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date).replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
