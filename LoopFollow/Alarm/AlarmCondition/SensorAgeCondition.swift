// LoopFollow
// SensorAgeCondition.swift

import Foundation

/// Fires when we are **≤ threshold hours** away from the
/// sensor's configured lifetime.
struct SensorAgeCondition: AlarmCondition {
    static let type: AlarmType = .sensorChange
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // 0. basic guards
        guard let warnAheadHrs = alarm.threshold, warnAheadHrs > 0 else { return false }
        guard let insertTS = data.sageInsertTime, insertTS > 0 else { return false }

        // convert UNIX timestamp to Date
        let insertedAt = Date(timeIntervalSince1970: insertTS)

        // 1. compute trigger moment using configurable lifetime (default 10 days)
        let lifetimeDays = alarm.sensorLifetimeDays ?? 10
        let lifetime: TimeInterval = Double(lifetimeDays) * 24 * 60 * 60
        let expiry = insertedAt.addingTimeInterval(lifetime)
        let trigger = expiry.addingTimeInterval(-warnAheadHrs * 3600)

        return Date() >= trigger
    }
}
