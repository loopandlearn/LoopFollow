//
//  AlarmType+timeUnit.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-16.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

extension AlarmType {
    /// What “unit” we use for snoozeDuration for this alarmType.
    var timeUnit: TimeUnit {
        switch self {
        case .buildExpire:
            return .day
        case .low, .high, .fastDrop, .fastRise,
             .missedReading, .notLooping, .missedBolus,
             .bolus, .recBolus,
             .overrideStart, .overrideEnd, .tempTargetStart,
             .tempTargetEnd:
            return .minute
        case .battery, .batteryDrop, .sensorChange, .pumpChange, .cob, .iob,
             .pump:
            return .hour
        }
    }
}

enum TimeUnit {
    case minute, hour, day

    /// How many seconds in one “unit”
    var seconds: TimeInterval {
        switch self {
        case .minute: return 60
        case .hour: return 60 * 60
        case .day: return 60 * 60 * 24
        }
    }

    /// A user-facing label
    var label: String {
        switch self {
        case .minute: return "min" // Changed from minutes to save ui space
        case .hour: return "hours"
        case .day: return "days"
        }
    }
}
