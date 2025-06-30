// LoopFollow
// COBCondition.swift
// Created by Jonas Björkert.

import Foundation

struct COBCondition: AlarmCondition {
    static let type: AlarmType = .cob
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now _: Date) -> Bool {
        guard let threshold = alarm.threshold, threshold > 0 else { return false }
        guard let cob = data.COB, cob >= threshold else {
            Storage.shared.lastCOBNotified.value = nil
            return false
        }

        if let last = Storage.shared.lastCOBNotified.value,
           !(cob > last)
        {
            return false
        }

        Storage.shared.lastCOBNotified.value = cob
        return true
    }
}
