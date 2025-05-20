// LoopFollow
// TempTargetStartCondition.swift
// Created by Jonas Björkert on 2025-05-14.

import Foundation

/// Fires once when a temp-target is activated.
struct TempTargetStartCondition: AlarmCondition {
    static let type: AlarmType = .tempTargetStart
    init() {}

    func evaluate(alarm _: Alarm, data: AlarmData, now: Date) -> Bool {
        guard let startTS = data.latestTempTargetStart, startTS > 0 else { return false }
        guard now.timeIntervalSince1970 - startTS <= 15 * 60 else { return false }

        let last = Storage.shared.lastTempTargetStartNotified.value ?? 0
        guard startTS > last else { return false }

        Storage.shared.lastTempTargetStartNotified.value = startTS
        return true
    }
}
