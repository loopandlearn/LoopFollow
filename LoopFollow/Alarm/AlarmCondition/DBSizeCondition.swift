// LoopFollow
// DBSizeCondition.swift

import Foundation

/// Fires when the Nightscout database has filled **≥ threshold percent**
/// of the size limit configured on the site (`DBSIZE_MAX`).
struct DBSizeCondition: AlarmCondition {
    static let type: AlarmType = .dbSize
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        guard let limitPercentage = alarm.threshold, limitPercentage > 0 else { return false }
        guard let usedPercentage = data.dbSizePercentage else { return false }

        return usedPercentage >= limitPercentage
    }
}
