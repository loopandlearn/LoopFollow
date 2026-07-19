// LoopFollow
// LowBGCondition.swift

import Foundation

/// Fires when:
/// • every BG in `persistentMinutes` (if set) **and** the latest BG are ≤ `threshold`; **or**
/// • any predicted BG within `predictiveMinutes` is ≤ `threshold`.
struct LowBGCondition: AlarmCondition {
    static let type: AlarmType = .low
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let belowBG = alarm.belowBG else { return false }

        func isLow(_ g: GlucoseValue) -> Bool {
            g.sgv > 0 && Double(g.sgv) <= belowBG
        }

        // ────────────────────────────────
        // 1. predictive low?
        // ────────────────────────────────
        var predictiveTrigger = false
        if let predictiveMinutes = alarm.predictiveMinutes,
           predictiveMinutes > 0,
           !data.predictionData.isEmpty
        {
            let lookAhead = min(
                data.predictionData.count,
                Int(ceil(Double(predictiveMinutes) / 5.0))
            )

            for i in 0 ..< lookAhead where isLow(data.predictionData[i]) {
                predictiveTrigger = true
                break
            }
        }

        // ────────────────────────────────
        // 2. persistent low window (ALL readings must be low)
        // ────────────────────────────────
        var persistentOK = true
        if let persistentMinutes = alarm.persistentMinutes,
           persistentMinutes > 0
        {
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
        // 3. rising BG suppression (optional)
        //    Stay silent while the latest reading is above the previous one;
        //    only alarm when BG is flat or still falling.
        // ────────────────────────────────
        if alarm.suppressIfRising, data.bgReadings.count >= 2 {
            let last = data.bgReadings[data.bgReadings.count - 1]
            let previous = data.bgReadings[data.bgReadings.count - 2]
            if last.sgv > 0, previous.sgv > 0, last.sgv > previous.sgv {
                return false
            }
        }

        // ────────────────────────────────
        // 4. final decision
        // ────────────────────────────────
        return persistentOK || predictiveTrigger
    }
}
