// LoopFollow
// SensorAgeCondition.swift
// Created by Jonas Björkert.

import Foundation

/// Fires once when we are **≤ threshold hours** away from the
/// Dexcom 10-day hard-stop.  No repeats once triggered.
struct SensorAgeCondition: AlarmCondition {
    static let type: AlarmType = .sensorChange
    init() {}

    /// Dexcom hard-stop = 10 days = 240 h
    private let lifetime: TimeInterval = 10 * 24 * 60 * 60

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // 0. basic guards
        guard let warnAheadHrs = alarm.threshold, warnAheadHrs > 0 else { return false }
        guard let insertTS = data.sageInsertTime else { return false }

        // convert UNIX timestamp to Date
        let insertedAt = Date(timeIntervalSince1970: insertTS)

        // 1. compute trigger moment
        let expiry = insertedAt.addingTimeInterval(lifetime)
        let trigger = expiry.addingTimeInterval(-warnAheadHrs * 3600)

        return Date() >= trigger
    }
}
