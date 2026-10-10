// LoopFollow
// AlarmType+timeUnit.swift

import Foundation

enum TimeUnit {
    case minute, hour, day, none

    /// How many seconds in one “unit”
    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .hour: return 60 * 60
        case .day: return 60 * 60 * 24
        case .none: return 0
        }
    }

    /// A user-facing label
    var label: String {
        switch self {
        case .minute: return String(localized: "min", comment: "Alarm time unit")
        case .hour: return String(localized: "hours", comment: "Alarm time unit")
        case .day: return String(localized: "days", comment: "Alarm time unit")
        case .none: return String(localized: "none", comment: "Alarm time unit")
        }
    }
}
