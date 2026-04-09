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

    static func sensorChange(threshold: Double?, lifetimeDays: Int? = 10) -> Self {
        var alarm = Alarm(type: .sensorChange)
        alarm.threshold = threshold
        alarm.sensorLifetimeDays = lifetimeDays
        return alarm
    }

    static func futureCarbs(threshold: Double = 45, delta: Double = 5) -> Self {
        var alarm = Alarm(type: .futureCarbs)
        alarm.threshold = threshold
        alarm.delta = delta
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
            IOB: nil,
            recentBoluses: [],
            latestBattery: level,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: []
        )
    }

    static func withSensorInsertTime(_ insertTime: TimeInterval?) -> Self {
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
            sageInsertTime: insertTime,
            pumpInsertTime: nil,
            latestPumpVolume: nil,
            IOB: nil,
            recentBoluses: [],
            latestBattery: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: []
        )
    }

    static func withCarbs(_ carbs: [CarbSample]) -> Self {
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
            IOB: nil,
            recentBoluses: [],
            latestBattery: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: carbs
        )
    }
}
