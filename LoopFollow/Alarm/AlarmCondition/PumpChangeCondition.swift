// LoopFollow
// PumpChangeCondition.swift
// Created by Jonas Björkert.

//
//  PumpChangeCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-17.
//

import Foundation

/// Fires once when we are **≤ threshold hours** away from the Omnipod /
/// cannula 3-day hard-stop.  Automatically disables itself after firing.
struct PumpChangeCondition: AlarmCondition {
    static let type: AlarmType = .pumpChange
    init() {}

    /// Pod lifetime = 3 days = 72 h
    private let lifetime: TimeInterval = 3 * 24 * 60 * 60

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // 0. sanity guards
        guard let warnAheadHrs = alarm.threshold, warnAheadHrs > 0 else { return false }
        guard let insertTS = data.pumpInsertTime else { return false }

        // convert UNIX timestamp → Date
        let insertedAt = Date(timeIntervalSince1970: insertTS)

        // 1. compute “fire-at” moment
        let expiry = insertedAt.addingTimeInterval(lifetime)
        let trigger = expiry.addingTimeInterval(-warnAheadHrs * 3600)

        return Date() >= trigger
    }
}
