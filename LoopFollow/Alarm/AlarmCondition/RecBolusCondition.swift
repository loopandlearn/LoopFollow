// LoopFollow
// RecBolusCondition.swift
// Created by Jonas Björkert.

import Foundation

/// Fires once when the recommended bolus (units) is ≥ the user-set threshold.
struct RecBolusCondition: AlarmCondition {
    static let type: AlarmType = .recBolus
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // ────────────────────────────────
        // Reset alarm if below threshold
        // ────────────────────────────────
        guard let threshold = alarm.threshold, threshold > 0 else { return false }
        guard let rec = data.recBolus, rec >= threshold else {
            Storage.shared.lastRecBolusNotified.value = nil
            return false
        }

        // ────────────────────────────────
        // Check if we should alert (increase or first time)
        // ────────────────────────────────
        let shouldAlert: Bool
        if let last = Storage.shared.lastRecBolusNotified.value {
            // Only alert if there's been more than 5% increase
            shouldAlert = rec > last * (1.05)
        } else {
            // First time above threshold - alert
            shouldAlert = true
        }

        // Always update the stored value when above threshold
        Storage.shared.lastRecBolusNotified.value = rec

        return shouldAlert
    }
}
