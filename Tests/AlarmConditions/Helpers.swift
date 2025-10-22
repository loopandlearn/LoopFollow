// LoopFollow
// Helpers.swift

// Tests/AlarmConditions/Helpers.swift
import Foundation
@testable import LoopFollow
import Testing

// MARK: - Alarm helpers

extension Alarm {
    static func battery(threshold: Double?) -> Self {
        var alarm = Alarm(type: .battery)
        alarm.threshold = threshold
        return alarm
    }
}

extension Alarm {
    static func pumpBattery(threshold: Double?) -> Self {
        var alarm = Alarm(type: .pumpBattery)
        alarm.threshold = threshold
        return alarm
    }
}

// MARK: - AlarmData helpers

extension AlarmData {
    static func withBattery(_ level: Double?) -> Self {
        AlarmData(
            bgReadings: [],
            predictionData: [],
            expireDate: nil,
            lastLoopTime: nil,
            latestOverrideStart: nil,
            latestOverrideEnd: nil,
            latestTempTargetStart: nil,
            latestTempTargetEnd: nil,
            recBolus: nil,
            COB: nil,
            sageInsertTime: nil,
            pumpInsertTime: nil,
            latestPumpVolume: nil,
            latestPumpBattery: nil,
            IOB: nil,
            recentBoluses: [],
            latestBattery: level,
            batteryHistory: [],
            recentCarbs: []
        )
    }

    static func withPumpBattery(_ level: Double?) -> Self {
        AlarmData(
            bgReadings: [],
            predictionData: [],
            expireDate: nil,
            lastLoopTime: nil,
            latestOverrideStart: nil,
            latestOverrideEnd: nil,
            latestTempTargetStart: nil,
            latestTempTargetEnd: nil,
            recBolus: nil,
            COB: nil,
            sageInsertTime: nil,
            pumpInsertTime: nil,
            latestPumpVolume: nil,
            latestPumpBattery: level,
            IOB: nil,
            recentBoluses: [],
            latestBattery: nil,
            batteryHistory: [],
            recentCarbs: []
        )
    }
}
