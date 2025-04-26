//
//  AlarmManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

class AlarmManager {
    static let shared = AlarmManager()

    private let evaluators: [AlarmType: AlarmCondition]
    private let config: AlarmConfiguration

    private init(
        config: AlarmConfiguration = .default,
        conditionTypes: [AlarmCondition.Type] = [
            BuildExpireCondition.self
            // …add your other condition types here
        ]
    ) {
        self.config = config
        var dict = [AlarmType: AlarmCondition]()
        conditionTypes.forEach { dict[$0.type] = $0.init() }
        evaluators = dict
    }

    func checkAlarms(data: AlarmData) {
        let context = AlarmContext(now: Date(), config: config)
        let alarms = Storage.shared.alarms.value

        let sorted = alarms.sorted { lhs, rhs in
            // Primary: type priority
            if lhs.type.priority != rhs.type.priority {
                return lhs.type.priority < rhs.type.priority
            }
            // Secondary: threshold ordering if applicable
            if let asc = lhs.type.thresholdSortAscending {
                let leftVal = lhs.threshold ?? (asc ? Float.infinity : -Float.infinity)
                let rightVal = rhs.threshold ?? (asc ? Float.infinity : -Float.infinity)
                return asc ? leftVal < rightVal : leftVal > rightVal
            }
            // Tertiary: fallback to insertion order
            return false
        }

        for alarm in sorted {
            guard let checker = evaluators[alarm.type],
                  checker.shouldFire(alarm: alarm, data: data, context: context)
            else { continue }
            alarm.trigger()
            break
        }
    }
}
