// LoopFollow
// IOBCondition.swift
// Created by Jonas Björkert.

//
//  IOBCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-17.
//

import Foundation

/// Fires when **any** of three rules is true
/// ──────────────────────────────────────────
///  1. latest IOB ≥ `threshold`
///  2. within the last `lookbackMinutes`, the **count** of boluses
///     ≥ `monitoringWindow` **and** each bolus ≥ `delta` units
///  3. within that same window, the **sum** of boluses ≥ `threshold`
struct IOBCondition: AlarmCondition {
    static let type: AlarmType = .iob
    init() {}

    /// Convenience accessors to keep the code tidy
    private struct Params {
        let iobMax: Double // alarm.threshold         (units)
        let minBolus: Double // alarm.delta             (units)
        let countNeeded: Int // alarm.monitoringWindow  (bolus count)
        let lookbackMin: Int // alarm.predictiveMinutes (minutes)

        init?(alarm: Alarm) {
            guard
                let iobMax = alarm.threshold,
                let minBolus = alarm.delta,
                let count = alarm.monitoringWindow,
                let mins = alarm.predictiveMinutes,
                iobMax > 0, minBolus > 0, count > 0, mins > 0
            else { return nil }

            self.iobMax = iobMax
            self.minBolus = minBolus
            countNeeded = count
            lookbackMin = mins
        }
    }

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // ── 0. pull and sanity-check parameters ────────────────────────────
        guard let p = Params(alarm: alarm) else { return false }

        // ── 1. latest IOB alone high enough? ───────────────────────────────
        if let iob = data.IOB, iob >= p.iobMax { return true }

        // ── 2. look at the recent boluses ──────────────────────────────────
        let cutoff = Date().addingTimeInterval(-Double(p.lookbackMin) * 60)

        var count = 0
        var total = 0.0

        for b in data.recentBoluses where b.date >= cutoff && b.units >= p.minBolus {
            count += 1
            total += b.units
            if count >= p.countNeeded || total >= p.iobMax { return true }
        }

        return false
    }
}
