// LoopFollow
// PumpVolumeCondition.swift
// Created by Jonas Björkert on 2025-05-17.

//
//  PumpVolumeCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-17.
//

import Foundation

/// Fires when the most-recent pump‐reservoir reading is **≤ threshold units**.
/// Re-fires after the user-chosen snooze expires.
struct PumpVolumeCondition: AlarmCondition {
    static let type: AlarmType = .pump
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        guard let threshold = alarm.threshold, threshold > 0 else { return false }
        guard let latestVol = data.latestPumpVolume else { return false }

        return latestVol <= threshold
    }
}
