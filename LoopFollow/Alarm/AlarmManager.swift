//
//  AlarmManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import UserNotifications

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
                let leftVal = lhs.threshold ?? (asc ? Double.infinity : -Double.infinity)
                let rightVal = rhs.threshold ?? (asc ? Double.infinity : -Double.infinity)
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

            // If the alarm itself is snoozed skip it, and skip lower‑priority alarms of the same type.
            // We still want other types af alarm to go off, so we continue here without breaking
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
                // If this alarm is active, but no longer fulfill the requirements, stop it.
                // Continue evaluating other alarams
                if Observable.shared.currentAlarm.value == alarm.id {
                    stopAlarm()
                }

                continue
            }

            // If this alarm is active, and still fulfill the requirements, let it be active
            // Break the loop, nothing else to do
            if Observable.shared.currentAlarm.value == alarm.id {
                break
            }

            // Fire the alarm and break the loop; we only allow one alarm per evaluation tick.
            Observable.shared.currentAlarm.value = alarm.id

            alarm.trigger(config: Storage.shared.alarmConfiguration.value, now: now)
            break
        }
    }

    func performSnooze(_ snoozeUnits: Int? = nil) {
        guard let alarmID = Observable.shared.currentAlarm.value else { return }
        var alarms = Storage.shared.alarms.value
        if let idx = alarms.firstIndex(where: { $0.id == alarmID }) {
            let alarm = alarms[idx]
            let units = snoozeUnits ?? alarm.snoozeDuration
            let snoozeSeconds = Double(units) * alarm.type.timeUnit.seconds
            alarms[idx].snoozedUntil = Date().addingTimeInterval(snoozeSeconds)
            Storage.shared.alarms.value = alarms
            stopAlarm()
        }
    }

    func stopAlarm() {
        AlarmSound.stop()
        Observable.shared.currentAlarm.value = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
