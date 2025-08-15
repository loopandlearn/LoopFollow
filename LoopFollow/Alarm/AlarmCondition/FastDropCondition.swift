// LoopFollow
// FastDropCondition.swift

import Foundation

struct FastDropCondition: AlarmCondition {
    static let type: AlarmType = .fastDrop
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        // ────────────────────────────────
        // 0. sanity checks
        // ────────────────────────────────
        guard
            let dropPerReading = alarm.delta, dropPerReading > 0,
            let dropsNeeded = alarm.monitoringWindow, dropsNeeded > 0,
            data.bgReadings.count >= dropsNeeded + 1
        else { return false }

        // ────────────────────────────────
        // 1. compute recent deltas
        //    (BG-limit check is now handled by passesBGLimits)
        // ────────────────────────────────
        let recent = data.bgReadings.suffix(dropsNeeded + 1)
        let readings = Array(recent)

        for i in 1 ... dropsNeeded {
            let delta = Double(readings[i - 1].sgv - readings[i].sgv)
            if delta < dropPerReading { return false }
        }
        return true
    }
}
