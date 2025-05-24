// LoopFollow
// AlarmType+canAcknowledge.swift
// Created by Jonas Björkert on 2025-05-24.

import Foundation

extension AlarmType {
    /// True if this alarm may be silenced with an “Acknowledge” by settings snooze time to 0
    var canAcknowledge: Bool {
        switch self {
        // These are alarms that typically has a "memory", they will only alarm once and acknowledge them is fine
        case .low, .high, .fastDrop, .fastRise, .temporary, .cob, .missedBolus, .recBolus, .overrideStart, .overrideEnd, .tempTargetStart, .tempTargetEnd:
            return true
        // These are alarms without memory, if they only are acknowledged - they would alarm again immediately
        case
            .batteryDrop, .missedReading, .notLooping, .battery, .buildExpire, .iob, .sensorChange, .pumpChange, .pump:
            return false
        }
    }
}
