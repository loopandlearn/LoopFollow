//
//  TempTargetEndCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

/// Fires once when the active temp target ends.
struct TempTargetEndCondition: AlarmCondition {
    static let type: AlarmType = .tempTargetEnd
    init() {}

    func evaluate(alarm _: Alarm, data: AlarmData) -> Bool {
        guard let endTS = data.latestTempTargetEnd, endTS > 0 else { return false }
        guard Date().timeIntervalSince1970 - endTS <= 15 * 60 else { return false }

        let last = Storage.shared.lastTempTargetEndNotified.value ?? 0
        guard endTS > last else { return false }

        Storage.shared.lastTempTargetEndNotified.value = endTS
        return true
    }
}
