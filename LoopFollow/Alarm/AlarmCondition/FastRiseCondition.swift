// LoopFollow
// FastRiseCondition.swift
// Created by Jonas Björkert on 2025-05-15.

import Foundation

/// Fires when N consecutive BG deltas are ≥ `delta` mg/dL.
struct FastRiseCondition: AlarmCondition {
    static let type: AlarmType = .fastRise
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        guard
            let rise = alarm.delta, rise > 0,
            let streak = alarm.monitoringWindow, streak > 0,
            data.bgReadings.count >= streak + 1
        else { return false }

        // grab the last (streak + 1) readings, newest last
        let recent = data.bgReadings.suffix(streak + 1).map(\.sgv)

        // every forward delta must hit the threshold
        return zip(recent.dropFirst(), recent).allSatisfy {
            Double($0 - $1) >= rise
        }
    }
}
