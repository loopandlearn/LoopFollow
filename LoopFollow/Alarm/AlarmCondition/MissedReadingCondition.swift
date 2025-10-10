// LoopFollow
// MissedReadingCondition.swift

import Foundation

/// Fires when the newest CGM reading is older than `threshold` minutes.
struct MissedReadingCondition: AlarmCondition {
    static let type: AlarmType = .missedReading
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let thresholdMinutes = alarm.threshold, thresholdMinutes > 0 else { return false }

        // Skip if we have *no* readings
        guard let last = data.bgReadings.last else { return false }

        guard let lastChecked = Storage.shared.lastBGChecked.value else {
            // Never checked, so don't alarm.
            return false
        }

        let checkedAgeSeconds = now.timeIntervalSince(lastChecked)
        if checkedAgeSeconds > 360 { // 6 minutes
            // The check itself is stale, so the data is unreliable. Don't alarm.
            return false
        }

        let secondsSinceLast = now.timeIntervalSince(last.date)
        return secondsSinceLast >= thresholdMinutes * 60
    }
}
