// LoopFollow
// AlarmData.swift

import Foundation

struct AlarmData: Codable {
    let bgReadings: [GlucoseValue]
    let predictionData: [GlucoseValue]
    let expireDate: Date?
    let lastLoopTime: TimeInterval?
    let latestOverrideStart: TimeInterval?
    let latestOverrideEnd: TimeInterval?
    let latestTempTargetStart: TimeInterval?
    let latestTempTargetEnd: TimeInterval?
    /// Scheduled end of the currently-active override/temp target, if known
    /// in advance — used by the end alarms' early warning.
    var activeOverrideEnd: TimeInterval?
    var activeTempTargetEnd: TimeInterval?
    let recBolus: Double?
    let COB: Double?
    let sageInsertTime: TimeInterval?
    let pumpInsertTime: TimeInterval?
    let latestPumpVolume: Double?
    let IOB: Double?
    let recentBoluses: [BolusEntry]
    let latestBattery: Double?
    let latestBatteryIsCharging: Bool?
    let latestPumpBattery: Double?
    let batteryHistory: [DataStructs.batteryStruct]
    let recentCarbs: [CarbSample]
    let dbSizePercentage: Double?
}
