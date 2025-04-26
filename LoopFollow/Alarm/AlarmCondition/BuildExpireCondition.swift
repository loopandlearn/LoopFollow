//
//  ExpireCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-18.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

struct BuildExpireCondition: AlarmCondition {
    static let type: AlarmType = .buildExpire
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData) -> Bool {
        guard let expiry = data.expireDate else { return false }
        guard let thresholdDays = alarm.threshold else { return false }

        let thresholdSeconds = TimeInterval(thresholdDays) * TimeUnit.day.seconds
        let thresholdDate = expiry.addingTimeInterval(-thresholdSeconds)

        return Date() >= thresholdDate
    }
}
