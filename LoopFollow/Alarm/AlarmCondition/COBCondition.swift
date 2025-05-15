//
//  COBCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

struct COBCondition: AlarmCondition {
    static let type: AlarmType = .cob
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
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
