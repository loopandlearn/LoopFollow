//
//  CycleHelper.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-01.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

enum CycleHelper {
    /// Returns a positive modulus value (always between 0 and modulus).
    static func positiveModulo(_ value: TimeInterval, modulus: TimeInterval) -> TimeInterval {
        let remainder = value.truncatingRemainder(dividingBy: modulus)
        return remainder < 0 ? remainder + modulus : remainder
    }

    /// Calculates the cycle offset for a given date relative to midnight.
    /// The offset is the number of seconds into the cycle (i.e., date mod interval).
    static func cycleOffset(for date: Date, interval: TimeInterval) -> TimeInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let secondsSinceMidnight = date.timeIntervalSince(startOfDay)
        return secondsSinceMidnight.truncatingRemainder(dividingBy: interval)
    }

    /// Same as above, but takes a timestamp (seconds since 1970) instead of a Date.
    static func cycleOffset(for timestamp: TimeInterval, interval: TimeInterval) -> TimeInterval {
        let date = Date(timeIntervalSince1970: timestamp)
        return cycleOffset(for: date, interval: interval)
    }

    /// Computes the delay experienced when using a heartbeat device to read a sensor value.
    /// The calculation is based on a sensor reference (Date) and sensor interval.
    /// All calculations assume midnight as the base reference.
    static func computeDelay(sensorReference: Date,
                             sensorInterval: TimeInterval,
                             heartbeatLast: Date,
                             heartbeatInterval: TimeInterval) -> TimeInterval
    {
        let sensorOffset = cycleOffset(for: sensorReference, interval: sensorInterval)
        let hbOffset = cycleOffset(for: heartbeatLast, interval: heartbeatInterval)
        return positiveModulo(hbOffset - sensorOffset, modulus: heartbeatInterval)
    }

    /// Overloaded version of computeDelay where the sensor cycle offset is already known.
    static func computeDelay(sensorOffset: TimeInterval,
                             heartbeatLast: Date,
                             heartbeatInterval: TimeInterval) -> TimeInterval
    {
        let hbOffset = cycleOffset(for: heartbeatLast, interval: heartbeatInterval)
        return positiveModulo(hbOffset - sensorOffset, modulus: heartbeatInterval)
    }
}
