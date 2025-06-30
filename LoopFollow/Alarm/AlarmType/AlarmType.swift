// LoopFollow
// AlarmType.swift
// Created by Jonas Björkert.

import Foundation

/// Categorizes alarms into distinct types, prioritized in the order they appear here.
/// Multiple user-defined alarms may share the same type but differ in configuration.
enum AlarmType: String, CaseIterable, Codable {
    case temporary = "Temporary Alert"
    case iob = "IOB Alert"
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
    /// `true` for alarms whose primary trigger is a blood-glucose value
    /// or its rate of change.
    var isBGBased: Bool {
        switch self {
        case .low, .high, .fastDrop, .fastRise, .missedReading, .temporary:
            return true
        default:
            return false
        }
    }
}
