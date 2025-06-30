// LoopFollow
// AlarmCondition.swift
// Created by Jonas Björkert.

import Foundation

protocol AlarmCondition {
    static var type: AlarmType { get }
    init()
    /// pure, per-alarm logic against `AlarmData`
    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool
}

extension AlarmCondition {
    /// Returns `true` when the alarm is allowed to continue evaluating
    /// after BG-limit checks; `false` blocks it immediately.
    func passesBGLimits(alarm: Alarm, data: AlarmData) -> Bool {
        let bgReading = data.bgReadings.last?.sgv
        let haveBG = (bgReading ?? 0) > 0
        let bgValue = Double(bgReading ?? 0)

        // ────────────────────────────────────
        // 1. BG-based alarms always need data
        // ────────────────────────────────────
        if alarm.type.isBGBased && !haveBG { return false }

        // ────────────────────────────────────
        // 2. No limits?  we’re done.
        // ────────────────────────────────────
        if alarm.belowBG == nil && alarm.aboveBG == nil { return true }

        // If we reach here, there *are* limits.
        // Non-BG alarms without a reading must fail;
        // BG-based alarms already bailed out above.
        guard haveBG else { return false }

        switch (alarm.belowBG, alarm.aboveBG) {
        case let (lo?, hi?):
            return lo < hi ? (bgValue <= lo || bgValue >= hi) // fire outside band
                : (hi <= bgValue && bgValue <= lo) // fire inside band

        case let (lo?, nil):
            return bgValue <= lo

        case let (nil, hi?):
            return bgValue >= hi

        default:
            return true
        }
    }

    /// applies every global & per-alarm guard exactly once
    func shouldFire(alarm: Alarm, data: AlarmData, now: Date, config: AlarmConfiguration) -> Bool {
        // master on/off
        guard alarm.isEnabled else { return false }
        // per-alarm snooze
        if let snooze = alarm.snoozedUntil, snooze > now { return false }

        if !passesBGLimits(alarm: alarm, data: data) { return false }

        // time-of-day guard
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowMin = (comps.hour! * 60) + comps.minute!
        let dStart = config.dayStart.minutesSinceMidnight
        let nStart = config.nightStart.minutesSinceMidnight
        let isNight = (nowMin < dStart) || (nowMin >= nStart)

        switch alarm.activeOption {
        case .always:
            break
        case .day:
            // only fire in day
            guard !isNight else { return false }
        case .night:
            // only fire in night
            guard isNight else { return false }
        }

        // finally, run the type-specific logic
        return evaluate(alarm: alarm, data: data, now: now)
    }
}
