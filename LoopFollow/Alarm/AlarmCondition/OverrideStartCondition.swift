// LoopFollow
// OverrideStartCondition.swift
// Created by Jonas Björkert.

import Foundation

struct OverrideStartCondition: AlarmCondition {
    static let type: AlarmType = .overrideStart
    init() {}

    func evaluate(alarm _: Alarm, data: AlarmData, now: Date) -> Bool {
        guard let startTS = data.latestOverrideStart, startTS > 0 else { return false }

        let recent = now.timeIntervalSince1970 - startTS <= 15 * 60
        guard recent else { return false }

        let lastNotified = Storage.shared.lastOverrideStartNotified.value ?? 0
        guard startTS > lastNotified else { return false }

        Storage.shared.lastOverrideStartNotified.value = startTS
        return true
    }
}
