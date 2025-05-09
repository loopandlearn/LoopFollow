//
//  LowBGCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-09.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

/// Fires when:
/// • every BG in `persistentMinutes` (if set) **and** the latest BG are ≤ `threshold`; **or**
/// • any predicted BG within `predictiveMinutes` is ≤ `threshold`.
struct LowBGCondition: AlarmCondition {
    static let type: AlarmType = .low
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let threshold = alarm.threshold else { return false }
        guard let latest = data.bgReadings.last, latest.sgv > 0 else { return false }

        func isLow(_ g: GlucoseValue) -> Bool {
            g.sgv > 0 && Double(g.sgv) <= threshold
        }

        // ────────────────────────────────
        // 1. predictive low?
        // ────────────────────────────────
        var predictiveTrigger = false
        if let predictiveMinutes = alarm.predictiveMinutes,
           predictiveMinutes > 0,
           !data.predictionData.isEmpty {

            let lookAhead = min(
                data.predictionData.count,
                Int(ceil(Double(predictiveMinutes) / 5.0))
            )

            for i in 0..<lookAhead where isLow(data.predictionData[i]) {
                predictiveTrigger = true
                break
            }
        }

        // ────────────────────────────────
        // 2. persistent low window (ALL readings must be low)
        // ────────────────────────────────
        var persistentOK = true
        if let persistentMinutes = alarm.persistentMinutes,
           persistentMinutes > 0 {

            let window = Int(ceil(Double(persistentMinutes) / 5.0))

            if data.bgReadings.count >= window {
                let recent = data.bgReadings.suffix(window)
                persistentOK = recent.allSatisfy(isLow)
            } else {
                // not enough samples to prove persistence ⇒ don’t alarm yet
                persistentOK = false
            }
        }

        // ────────────────────────────────
        // 3. final decision
        // ────────────────────────────────
        let currentLow = isLow(latest)
        return (currentLow && persistentOK) || predictiveTrigger
    }
}
