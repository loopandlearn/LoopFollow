// LoopFollow
// MissedBolusCondition.swift
// Created by Jonas Björkert on 2025-05-20.

import Foundation

/// Fires when a carb entry is logged but **no** qualifying bolus is given
/// within the user-defined “delay” (after allowing for a pre-bolus window).
/// • Ignores small-carb treatments, tiny boluses, and low-BG scenarios.
/// • Triggers once per carb entry.
struct MissedBolusCondition: AlarmCondition {
    static let type: AlarmType = .missedBolus
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        // ────────────────────────────────
        // 0. pull user settings
        // ────────────────────────────────
        guard
            let delayMin = alarm.monitoringWindow, delayMin > 0,
            let prebolusMin = alarm.predictiveMinutes,
            let minBolusU = alarm.delta, // ignore bolus ≤
            let minCarbGr = alarm.threshold, // ignore carbs ≤
            let minBG = alarm.aboveBG // ignore BG ≤
        else { return false }

        // ────────────────────────────────
        // 1. get most-recent carb entry
        // ────────────────────────────────
        guard let carb = data.recentCarbs.last else { return false }

        //  – must be at least `delayMin` old, but not older than 60 min
        guard carb.date > now.addingTimeInterval(-3600),
              carb.date < now.addingTimeInterval(-Double(delayMin) * 60)
        else { return false }

        //  – ignore tiny carbs
        guard carb.grams > minCarbGr else { return false }

        //  – ignore if BG is low
        if let latestBG = data.bgReadings.last,
           Double(latestBG.sgv) <= minBG { return false }

        // ────────────────────────────────
        // 2. already alerted for this carb?
        // ────────────────────────────────
        if let lastFired = Storage.shared.lastMissedBolusNotified.value,
           carb.date <= lastFired { return false }

        // ────────────────────────────────
        // 3. look for a valid bolus
        // ────────────────────────────────
        let windowStart = carb.date.addingTimeInterval(-Double(prebolusMin) * 60)

        let hasBolus = data.recentBoluses.contains { bolus in
            bolus.date >= windowStart && bolus.units > minBolusU
        }
        guard !hasBolus else { return false }

        // ────────────────────────────────
        // 4. trigger!
        // ────────────────────────────────
        Storage.shared.lastMissedBolusNotified.value = carb.date
        return true
    }
}
