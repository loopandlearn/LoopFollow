//
//  AlarmCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-18.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

protocol AlarmCondition {
    static var type: AlarmType { get }
    init()
    /// pure, per-alarm logic against `AlarmData`
    func evaluate(alarm: Alarm, data: AlarmData) -> Bool
}

extension AlarmCondition {
    /// applies every global & per-alarm guard exactly once
    func shouldFire(alarm: Alarm, data: AlarmData, context: AlarmContext) -> Bool {
        // master on/off
        guard alarm.isEnabled else { return false }
        // global mute
        if let until = context.config.muteUntil, until > context.now { return false }
        // per-alarm snooze
        if let snooze = alarm.snoozedUntil, snooze > context.now { return false }

        // time-of-day guard
        let comps   = Calendar.current.dateComponents([.hour, .minute], from: context.now)
        let nowMin  = (comps.hour! * 60) + comps.minute!
        let dStart  = context.config.dayStart.minutesSinceMidnight
        let nStart  = context.config.nightStart.minutesSinceMidnight
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
        return evaluate(alarm: alarm, data: data)
    }
}
