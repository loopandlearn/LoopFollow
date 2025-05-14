//
//  HighBGCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

/// Fires when **every** BG in `persistentMinutes` (if set) **and** the latest BG
/// are ≥ `threshold`.
/// — No predictive branch for highs.
struct HighBGCondition: AlarmCondition {
    static let type: AlarmType = .high
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let threshold = alarm.threshold else { return false }
        guard let latest = data.bgReadings.last, latest.sgv > 0 else { return false }

        func isHigh(_ g: GlucoseValue) -> Bool {
            g.sgv > 0 && Double(g.sgv) >= threshold
        }

        // ────────────────────────────────
        // 1. persistent-window guard
        // ────────────────────────────────
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

        // ────────────────────────────────
        // 2. final decision
        // ────────────────────────────────
        let currentHigh = isHigh(latest)
        return currentHigh && persistentOK
    }
}
