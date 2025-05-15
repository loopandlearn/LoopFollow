//
//  FastRiseCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-15.
//

import Foundation

struct FastRiseCondition: AlarmCondition {
    static let type: AlarmType = .fastRise
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        guard
            let risePerReading = alarm.delta, risePerReading > 0,
            let risesNeeded = alarm.monitoringWindow, risesNeeded > 0,
            data.bgReadings.count >= risesNeeded + 1
        else { return false }

        if let limit = alarm.threshold {
            guard let latest = data.bgReadings.last, latest.sgv > 0 else { return false }
            guard Double(latest.sgv) > limit else { return false }
        }

        let recent = data.bgReadings.suffix(risesNeeded + 1)
        let readings = Array(recent)

        for i in 1 ... risesNeeded {
            let delta = Double(readings[i].sgv - readings[i - 1].sgv)
            if delta < risePerReading { return false }
        }
        return true
    }
}
