// LoopFollow
// NotLoopingCondition.swift

import Foundation

struct NotLoopingCondition: AlarmCondition {
    static let type: AlarmType = .notLooping
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let thresholdMinutes = alarm.threshold,
              thresholdMinutes > 0 else { return false }

        // We need a valid timestamp (seconds-since-1970) of the last Loop run.
        guard let lastLoopTime = data.lastLoopTime,
              lastLoopTime > 0 else { return false }

        guard let lastChecked = Storage.shared.lastLoopingChecked.value else {
            // Never checked, so don't alarm.
            return false
        }

        let checkedAgeSeconds = now.timeIntervalSince(lastChecked)
        if checkedAgeSeconds > 360 { // 6 minutes
            // The check itself is stale, so the data is unreliable. Don't alarm.
            return false
        }

        // ────────────────────────────────
        // 1. elapsed-time test
        // ────────────────────────────────
        let elapsedSecs = Date().timeIntervalSince1970 - lastLoopTime
        let limitSecs = thresholdMinutes * 60

        return elapsedSecs >= limitSecs
    }
}
