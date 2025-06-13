// LoopFollow
// Alarm+byPriorityThenSpec.swift
// Created by Jonas Björkert on 2025-06-12.

import Foundation

extension Alarm {
    /// Sorts by `AlarmType.priority`, then the per-type `sortSpec` if one exists.
    static let byPriorityThenSpec: (Alarm, Alarm) -> Bool = { lhs, rhs in
        // 1) type-level priority
        if lhs.type.priority != rhs.type.priority {
            return lhs.type.priority < rhs.type.priority
        }

        // 2) per-type “main value” ordering
        if lhs.type == rhs.type,
           let spec = lhs.type.sortSpec
        {
            let lv = spec.key(lhs)
            let rv = spec.key(rhs)

            switch spec.direction {
            case .ascending: return (lv ?? .infinity) < (rv ?? .infinity)
            case .descending: return (lv ?? -.infinity) > (rv ?? -.infinity)
            }
        }

        // 3) fallback – keep original insertion order
        return false
    }
}
