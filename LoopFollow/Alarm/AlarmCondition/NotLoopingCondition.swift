// LoopFollow
// NotLoopingCondition.swift
// Created by Jonas Björkert on 2025-05-14.

import Foundation

struct NotLoopingCondition: AlarmCondition {
    static let type: AlarmType = .notLooping
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard let thresholdMinutes = alarm.threshold,
              thresholdMinutes > 0 else { return false }

        // We need a valid timestamp (seconds-since-1970) of the last Loop run.
        guard let lastLoopTime = data.lastLoopTime,
              lastLoopTime > 0 else { return false }

        // ────────────────────────────────
        // 1. elapsed-time test
        // ────────────────────────────────
        let elapsedSecs = Date().timeIntervalSince1970 - lastLoopTime
        let limitSecs = thresholdMinutes * 60

        return elapsedSecs >= limitSecs
    }
}
