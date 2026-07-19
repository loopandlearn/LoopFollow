// LoopFollow
// BatteryCondition.swift

import Foundation

struct BatteryCondition: AlarmCondition {
    static let type: AlarmType = .battery
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        guard let limit = alarm.threshold, limit > 0 else { return false }
        guard let level = data.latestBattery else { return false }

        // Optional: stay silent while the phone is charging back up.
        if alarm.suppressIfCharging, data.latestBatteryIsCharging == true {
            return false
        }

        return level <= limit
    }
}
