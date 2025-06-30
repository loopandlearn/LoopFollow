// LoopFollow
// AlarmType+timeUnit.swift
// Created by Jonas Björkert.

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
        case .minute: return "min"
        case .hour: return "hours"
        case .day: return "days"
        case .none: return "none"
        }
    }
}
