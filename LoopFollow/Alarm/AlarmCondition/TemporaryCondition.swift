// LoopFollow
// TemporaryCondition.swift
// Created by Jonas Björkert.

import Foundation

/// A throw-away, single-fire BG-limit alarm.
struct TemporaryCondition: AlarmCondition {
    static let type: AlarmType = .temporary
    init() {}

    func evaluate(alarm: Alarm, data _: AlarmData, now _: Date) -> Bool {
        // Needs at least ONE limit
        guard alarm.belowBG != nil || alarm.aboveBG != nil else { return false }

        // BG-limit checks are handled in shouldFire → passesBGLimits.
        // If we get here, the limits are satisfied ⇒ fire.
        return true
    }
}
