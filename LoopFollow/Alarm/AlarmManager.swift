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
    private var lastBGAlarmTime: Date?

    private init(
        conditionTypes: [AlarmCondition.Type] = [
            BuildExpireCondition.self,
            LowBGCondition.self,
            HighBGCondition.self,
            FastDropCondition.self,
            NotLoopingCondition.self,
            OverrideStartCondition.self,
            OverrideEndCondition.self,
            TempTargetStartCondition.self,
            TempTargetEndCondition.self,
            RecBolusCondition.self,
            COBCondition.self,
            MissedReadingCondition.self,
            FastRiseCondition.self,
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
            // 1) type-level priority (hard-coded table in AlarmType)
            if lhs.type.priority != rhs.type.priority {
                return lhs.type.priority < rhs.type.priority
            }

            // 2) per-type “main value” ordering
            if lhs.type == rhs.type, // only makes sense within the same type
               let spec = lhs.type.sortSpec
            { // (direction, key extractor)
                let lv = spec.key(lhs)
                let rv = spec.key(rhs)

                switch spec.direction {
                case .ascending: // smaller ⇒ more urgent
                    return (lv ?? Double.infinity) < (rv ?? Double.infinity)
                case .descending: // bigger  ⇒ more urgent
                    return (lv ?? -Double.infinity) > (rv ?? -Double.infinity)
                }
            }

            // 3) fallback – keep original insertion order
            return false
        }
        var skipType: AlarmType?

        let isLatestReadingRecent: Bool = {
            guard let last = data.bgReadings.last else { return false }
            return now.timeIntervalSince(last.date) <= 5 * 60
        }()

        for alarm in sorted {
            // If there is already an active (snoozed) alarm of this type, skip to next [type]
            if alarm.type == skipType {
                continue
            }

            // If the alarm is based on bg values, and the value isnt recent, skip to next
            if alarm.type.isBGBased, !isLatestReadingRecent {
                continue
            }

            // If this is a bg-based alarm and we've already handled that same BG reading,
            // skip until we see a newer one.
            if alarm.type.isBGBased,
               let lastHandled = lastBGAlarmTime,
               let latestDate = data.bgReadings.last?.date,
               !(latestDate > lastHandled)
            {
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

            // Store the latest bg time so we don't use it again
            if alarm.type.isBGBased,
               let latestDate = data.bgReadings.last?.date
            {
                lastBGAlarmTime = latestDate
            }
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
