// LoopFollow
// MissedReadingCondition.swift

import Foundation

/// Fires when the newest CGM reading is older than `threshold` minutes.
struct MissedReadingCondition: AlarmCondition {
    static let type: AlarmType = .missedReading
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now : Date) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let thresholdMinutes = alarm.threshold, thresholdMinutes > 0 else { return false }

        // Skip if we have *no* readings
        guard let last = data.bgReadings.last else { return false }

        let secondsSinceLast = now.timeIntervalSince(last.date)
        return secondsSinceLast >= thresholdMinutes * 60
    }
}
