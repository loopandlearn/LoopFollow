// LoopFollow
// RecBolusCondition.swift
// Created by Jonas Björkert on 2025-05-15.

import Foundation

/// Fires once when the recommended bolus (units) is ≥ the user-set threshold.
struct RecBolusCondition: AlarmCondition {
    static let type: AlarmType = .recBolus
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let threshold = alarm.threshold, threshold > 0 else { return false }
        guard let rec = data.recBolus, rec >= threshold else {
            Storage.shared.lastRecBolusNotified.value = nil
            return false
        }

        // ────────────────────────────────
        // 1. has it INCREASED past the last-notified value?
        // ────────────────────────────────
        if let last = Storage.shared.lastRecBolusNotified.value {
            if rec <= last + 1e-4 { return false }
        }

        Storage.shared.lastRecBolusNotified.value = rec
        return true
    }
}
