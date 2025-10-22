// LoopFollow
// PumpBatteryCondition.swift

import Foundation

struct PumpBatteryCondition: AlarmCondition {
    static let type: AlarmType = .pumpBattery
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        guard let limit = alarm.threshold, limit > 0 else { return false }
        guard let level = data.latestPumpBattery else { return false }

        return level <= limit
    }
}
