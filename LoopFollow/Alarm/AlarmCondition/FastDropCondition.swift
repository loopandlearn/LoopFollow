//
//  FastDropCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

struct FastDropCondition: AlarmCondition {
    static let type: AlarmType = .fastDrop
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard
            let dropPerReading = alarm.delta, dropPerReading > 0,
            let dropsNeeded = alarm.monitoringWindow, dropsNeeded > 0,
            data.bgReadings.count >= dropsNeeded + 1
        else { return false }

        // optional BG-limit guard
        if let limit = alarm.threshold {
            guard let latest = data.bgReadings.last, latest.sgv > 0 else { return false }
            guard Double(latest.sgv) < limit else { return false }
        }

        // ────────────────────────────────
        // 1. compute recent deltas
        // ────────────────────────────────
        let recent = data.bgReadings.suffix(dropsNeeded + 1)
        let readings = Array(recent)

        for i in 1...dropsNeeded {
            let delta = Double(readings[i - 1].sgv - readings[i].sgv)
            if delta < dropPerReading { return false }
        }

        return true
    }
}
