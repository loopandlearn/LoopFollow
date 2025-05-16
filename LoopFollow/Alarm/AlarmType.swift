//
//  AlarmType.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

/// Categorizes alarms into distinct types, prioritized in the order they appear here.
/// Multiple user-defined alarms may share the same type but differ in configuration.
enum AlarmType: String, CaseIterable, Codable {
    case iob = "IOB Alert"
    case bolus = "Bolus Alert"
    case cob = "COB Alert"
    case low = "Low BG Alert"
    case high = "High BG Alert"
    case fastDrop = "Fast Drop Alert"
    case fastRise = "Fast Rise Alert"
    case missedReading = "Missed Reading Alert"
    case notLooping = "Not Looping Alert"
    case missedBolus = "Missed Bolus Alert"
    case sensorChange = "Sensor Change Alert"
    case pumpChange = "Pump Change Alert"
    case pump = "Pump Insulin Alert"
    case battery = "Low Battery"
    case batteryDrop = "Battery Drop"
    case recBolus = "Rec. Bolus"
    case overrideStart = "Override Started"
    case overrideEnd = "Override Ended"
    case tempTargetStart = "Temp Target Started"
    case tempTargetEnd = "Temp Target Ended"
    case buildExpire = "Looping app expiration"
}

extension AlarmType {
    var priority: Int {
        return AlarmType.allCases.firstIndex(of: self) ?? 0
    }
}

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

extension AlarmType {
    /// `true` for alarms whose primary trigger is a blood-glucose value
    /// or its rate of change.
    var isBGBased: Bool {
        switch self {
        case .low, .high, .fastDrop, .fastRise, .missedReading:
            return true
        default:
            return false
        }
    }
}
