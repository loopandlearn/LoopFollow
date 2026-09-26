// LoopFollow
// AlarmType.swift

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
    case futureCarbs = "Future Carbs Alert"
    case sensorChange = "Sensor Change Alert"
    case pumpChange = "Pump Change Alert"
    case pump = "Pump Insulin Alert"
    case pumpBattery = "Pump Battery Alert"
    case battery = "Low Battery"
    case batteryDrop = "Battery Drop"
    case recBolus = "Rec. Bolus"
    case overrideStart = "Override Started"
    case overrideEnd = "Override Ended"
    case tempTargetStart = "Temp Target Started"
    case tempTargetEnd = "Temp Target Ended"
    case buildExpire = "Looping app expiration"
    case dbSize = "Nightscout Database Size"
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

extension AlarmType {
    /// User-facing, localized name. `rawValue` is persisted in Storage and must never be
    /// shown to the user or translated; every display site goes through this property.
    var displayName: String {
        switch self {
        case .temporary: String(localized: "Temporary Alert", comment: "Alarm type name")
        case .iob: String(localized: "IOB Alert", comment: "Alarm type name")
        case .cob: String(localized: "COB Alert", comment: "Alarm type name")
        case .low: String(localized: "Low BG Alert", comment: "Alarm type name")
        case .high: String(localized: "High BG Alert", comment: "Alarm type name")
        case .fastDrop: String(localized: "Fast Drop Alert", comment: "Alarm type name")
        case .fastRise: String(localized: "Fast Rise Alert", comment: "Alarm type name")
        case .missedReading: String(localized: "Missed Reading Alert", comment: "Alarm type name")
        case .notLooping: String(localized: "Not Looping Alert", comment: "Alarm type name")
        case .missedBolus: String(localized: "Missed Bolus Alert", comment: "Alarm type name")
        case .futureCarbs: String(localized: "Future Carbs Alert", comment: "Alarm type name")
        case .sensorChange: String(localized: "Sensor Change Alert", comment: "Alarm type name")
        case .pumpChange: String(localized: "Pump Change Alert", comment: "Alarm type name")
        case .pump: String(localized: "Pump Insulin Alert", comment: "Alarm type name")
        case .pumpBattery: String(localized: "Pump Battery Alert", comment: "Alarm type name")
        case .battery: String(localized: "Low Battery", comment: "Alarm type name")
        case .batteryDrop: String(localized: "Battery Drop", comment: "Alarm type name")
        case .recBolus: String(localized: "Rec. Bolus", comment: "Alarm type name: recommended bolus")
        case .overrideStart: String(localized: "Override Started", comment: "Alarm type name")
        case .overrideEnd: String(localized: "Override Ended", comment: "Alarm type name")
        case .tempTargetStart: String(localized: "Temp Target Started", comment: "Alarm type name")
        case .tempTargetEnd: String(localized: "Temp Target Ended", comment: "Alarm type name")
        case .buildExpire: String(localized: "Looping app expiration", comment: "Alarm type name")
        case .dbSize: String(localized: "Nightscout Database Size", comment: "Alarm type name")
        }
    }
}
