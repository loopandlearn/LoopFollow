// LoopFollow
// HighBGCondition.swift
// Created by Jonas Björkert on 2025-05-09.

import Foundation

/// Fires when the latest BG – and, if requested, every BG in a persistent-window – is **≥ aboveBG**.
struct HighBGCondition: AlarmCondition {
    static let type: AlarmType = .high
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        // ────────────────────────────────
        // 0. get the limit
        // ────────────────────────────────
        guard let high = alarm.aboveBG else { return false }

        func isHigh(_ g: GlucoseValue) -> Bool {
            g.sgv > 0 && Double(g.sgv) >= high
        }

        // we already know from `passesBGLimits` that the **latest** reading is ≥ high,
        // but we still need to honour the “persistent for N minutes” option.
        var persistentOK = true
        if let persistentMinutes = alarm.persistentMinutes,
           persistentMinutes > 0
        {
            let window = Int(ceil(Double(persistentMinutes) / 5.0))

            if data.bgReadings.count >= window {
                let recent = data.bgReadings.suffix(window)
                persistentOK = recent.allSatisfy(isHigh)
            } else {
                // not enough samples yet ⇒ don’t alarm
                persistentOK = false
            }
        }

        return persistentOK
    }
}
