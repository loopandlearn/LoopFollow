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

    static func low(belowBG: Double?, predictiveMinutes: Int? = nil, persistentMinutes: Int? = nil) -> Self {
        var alarm = Alarm(type: .low)
        alarm.belowBG = belowBG
        alarm.predictiveMinutes = predictiveMinutes
        alarm.persistentMinutes = persistentMinutes
        return alarm
    }

    static func fastDrop(delta: Double?, window: Int?) -> Self {
        var alarm = Alarm(type: .fastDrop)
        alarm.delta = delta
        alarm.monitoringWindow = window
        return alarm
    }

    static func tempTargetEnd(warnBefore: Int? = nil) -> Self {
        var alarm = Alarm(type: .tempTargetEnd)
        alarm.predictiveMinutes = warnBefore
        return alarm
    }

    static func overrideEnd(warnBefore: Int? = nil) -> Self {
        var alarm = Alarm(type: .overrideEnd)
        alarm.predictiveMinutes = warnBefore
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
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
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
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
        )
    }

    /// Builds an `AlarmData` from a list of glucose values ordered **oldest →
    /// newest** (the same order the app stores them; `bgReadings.last` is the most
    /// recent reading). Readings are spaced 5 minutes apart ending now.
    static func withReadings(_ sgvs: [Int]) -> Self {
        let now = Date()
        let last = sgvs.count - 1
        let readings = sgvs.enumerated().map { offset, sgv in
            GlucoseValue(sgv: sgv, date: now.addingTimeInterval(Double(offset - last) * 300))
        }
        return AlarmData(
            bgReadings: readings,
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
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
        )
    }

    static func withGlucose(readings: [GlucoseValue] = [], prediction: [GlucoseValue] = []) -> Self {
        AlarmData(
            bgReadings: readings,
            predictionData: prediction,
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
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
        )
    }

    static func withTempTargetEnds(latestEnd: TimeInterval? = nil, activeEnd: TimeInterval? = nil) -> Self {
        AlarmData(
            bgReadings: [],
            predictionData: [],
            expireDate: nil,
            lastLoopTime: nil,
            latestOverrideStart: nil,
            latestOverrideEnd: nil,
            latestTempTargetStart: nil,
            latestTempTargetEnd: latestEnd,
            activeOverrideEnd: nil,
            activeTempTargetEnd: activeEnd,
            recBolus: nil,
            COB: nil,
            sageInsertTime: nil,
            pumpInsertTime: nil,
            latestPumpVolume: nil,
            IOB: nil,
            recentBoluses: [],
            latestBattery: nil,
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
        )
    }

    static func withOverrideEnds(latestEnd: TimeInterval? = nil, activeEnd: TimeInterval? = nil) -> Self {
        AlarmData(
            bgReadings: [],
            predictionData: [],
            expireDate: nil,
            lastLoopTime: nil,
            latestOverrideStart: nil,
            latestOverrideEnd: latestEnd,
            latestTempTargetStart: nil,
            latestTempTargetEnd: nil,
            activeOverrideEnd: activeEnd,
            activeTempTargetEnd: nil,
            recBolus: nil,
            COB: nil,
            sageInsertTime: nil,
            pumpInsertTime: nil,
            latestPumpVolume: nil,
            IOB: nil,
            recentBoluses: [],
            latestBattery: nil,
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
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
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: carbs,
            dbSizePercentage: nil
        )
    }
}
