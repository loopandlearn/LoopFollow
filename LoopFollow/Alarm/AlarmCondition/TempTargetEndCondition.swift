// LoopFollow
// TempTargetEndCondition.swift
// Created by Jonas Björkert.

import Foundation

/// Fires once when the active temp target ends.
struct TempTargetEndCondition: AlarmCondition {
    static let type: AlarmType = .tempTargetEnd
    init() {}

    func evaluate(alarm _: Alarm, data: AlarmData, now: Date) -> Bool {
        guard let endTS = data.latestTempTargetEnd, endTS > 0 else { return false }
        guard now.timeIntervalSince1970 - endTS <= 15 * 60 else { return false }

        let last = Storage.shared.lastTempTargetEndNotified.value ?? 0
        guard endTS > last else { return false }

        Storage.shared.lastTempTargetEndNotified.value = endTS
        return true
    }
}
