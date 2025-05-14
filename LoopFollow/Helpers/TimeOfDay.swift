//
//  TimeOfDay.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-20.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

/// A time‐of‐day independent of any date
struct TimeOfDay: Codable, Equatable {
    let hour: Int // 0…23
    let minute: Int // 0…59

    /// total minutes since midnight
    var minutesSinceMidnight: Int { hour * 60 + minute }

    init(hour: Int, minute: Int) {
        precondition((0 ... 23).contains(hour))
        precondition((0 ... 59).contains(minute))
        self.hour = hour
        self.minute = minute
    }
}
