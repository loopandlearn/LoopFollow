// LoopFollow
// AlarmConfiguration.swift
// Created by Jonas Björkert.

import Foundation

struct AlarmConfiguration: Codable, Equatable {
    // MARK: Core

    var snoozeUntil: Date?
    var muteUntil: Date?
    var dayStart: TimeOfDay
    var nightStart: TimeOfDay

    // MARK: System audio overrides

    var overrideSystemOutputVolume: Bool
    var forcedOutputVolume: Float // 0 … 1
    var audioDuringCalls: Bool
    var ignoreZeroBG: Bool
    var autoSnoozeCGMStart: Bool
    var enableVolumeButtonSnooze: Bool

    static let `default` = AlarmConfiguration(
        muteUntil: nil,
        dayStart: TimeOfDay(hour: 6, minute: 0),
        nightStart: TimeOfDay(hour: 22, minute: 0),
        overrideSystemOutputVolume: true,
        forcedOutputVolume: 0.5,
        audioDuringCalls: true,
        ignoreZeroBG: true,
        autoSnoozeCGMStart: false,
        enableVolumeButtonSnooze: false
    )
}
