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

    private init(
        conditionTypes: [AlarmCondition.Type] = [
            BuildExpireCondition.self
            // TODO: add other condition types here
        ]
    ) {
        var dict = [AlarmType: AlarmCondition]()
        conditionTypes.forEach { dict[$0.type] = $0.init() }
        evaluators = dict
    }

    //TODO: Somehow we need to silent the current alarm if the current one is no longer active.
    func checkAlarms(data: AlarmData) {
        let now = Date()
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
        var skipType: AlarmType? = nil

        for alarm in sorted {
            // If there is already an active (snoozed) alarm of this type, skip to next [type]
            if alarm.type == skipType {
                continue
            }

            // If the alarm itself is snoozed, skip lower‑priority alarms of the same type.
            if let until = alarm.snoozedUntil, until > now {
                skipType = alarm.type
                continue
            }

            // Evaluate the alarm condition.
            guard let checker = evaluators[alarm.type],
                  checker
                .shouldFire(
                    alarm: alarm,
                    data: data,
                    now: now,
                    config: Storage.shared.alarmConfiguration.value
                )
            else {
                continue
            }

            // Fire the alarm and break the loop; we only allow one alarm per evaluation tick.
            Observable.shared.currentAlarm.value = alarm.id

            alarm.trigger(config: Storage.shared.alarmConfiguration.value, now: now)
            break
        }
    }

    //TODO: Handle default snooze for notofication snoze
    //TODO: Check interval type handling
    func performSnooze(_ minutes: Int? = nil) {
        if let alarmID = Observable.shared.currentAlarm.value {
            var alarms = Storage.shared.alarms.value
            if let idx = alarms.firstIndex(where: { $0.id == alarmID }) {
                alarms[idx].snoozedUntil = Date().addingTimeInterval(
                    TimeInterval((minutes ?? 5) * 60)) // fix default value
            }
            Storage.shared.alarms.value = alarms

            AlarmSound.stop()
            Observable.shared.currentAlarm.value = nil
        }
    }
}
