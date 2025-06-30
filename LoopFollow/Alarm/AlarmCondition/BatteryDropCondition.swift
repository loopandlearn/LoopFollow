// LoopFollow
// BatteryDropCondition.swift
// Created by Jonas Björkert.

import Foundation

/// Fires when the phone-battery **falls by ≥ Δ % within N minutes**.
///
/// * `alarm.delta`   ➜ percentage drop (e.g. 5 %)
/// * `alarm.monitoringWindow` ➜ window in minutes (e.g. 15)
/// * Uses `data.batteryHistory`, which must be sorted **oldest → newest**.
struct BatteryDropCondition: AlarmCondition {
    static let type: AlarmType = .batteryDrop
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // ───── 0. sanity ───────────────────────────────────────────────
        guard
            let drop = alarm.delta, drop > 0,
            let minutes = alarm.monitoringWindow, minutes > 0,
            let latest = data.batteryHistory.last
        else { return false }

        // find the sample *closest* to “minutes” ago
        let target = latest.timestamp.addingTimeInterval(-Double(minutes) * 60)

        guard let earlier = data.batteryHistory.min(by: {
            abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target))
        }) else { return false }

        // ignore if the earlier level was 100 % (false drop when just unplugged)
        guard earlier.batteryLevel < 100 else { return false }

        return (earlier.batteryLevel - latest.batteryLevel) >= drop
    }
}
