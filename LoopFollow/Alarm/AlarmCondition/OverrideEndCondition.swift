//
//  OverrideEndCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

struct OverrideEndCondition: AlarmCondition {
    static let type: AlarmType = .overrideEnd
    init() {}

    func evaluate(alarm _: Alarm, data: AlarmData) -> Bool {
        guard let endTS = data.latestOverrideEnd, endTS > 0 else { return false }
        guard Date().timeIntervalSince1970 - endTS <= 15 * 60 else { return false }

        let last = Storage.shared.lastOverrideEndNotified.value ?? 0
        guard endTS > last else { return false }

        Storage.shared.lastOverrideEndNotified.value = endTS
        return true
    }
}
