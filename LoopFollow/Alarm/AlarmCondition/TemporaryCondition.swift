//
//  TemporaryCondition.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-16.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

/// A throw-away, single-fire BG-limit alarm.
struct TemporaryCondition: AlarmCondition {
    static let type: AlarmType = .temporary
    init() {}

    func evaluate(alarm: Alarm, data _: AlarmData) -> Bool {
        // Needs at least ONE limit
        guard alarm.belowBG != nil || alarm.aboveBG != nil else { return false }

        // BG-limit checks are handled in shouldFire → passesBGLimits.
        // If we get here, the limits are satisfied ⇒ fire.
        return true
    }
}
