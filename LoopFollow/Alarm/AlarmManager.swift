// LoopFollow
// AlarmManager.swift

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
            TemporaryCondition.self,
            SensorAgeCondition.self,
            PumpChangeCondition.self,
            PumpVolumeCondition.self,
            IOBCondition.self,
            BatteryCondition.self,
            BatteryDropCondition.self,
            PumpBatteryCondition.self,
        ]
    ) {
        var dict = [AlarmType: AlarmCondition]()
        conditionTypes.forEach { dict[$0.type] = $0.init() }
        evaluators = dict
    }

    func checkAlarms(data: AlarmData) {
        let now = Date()
        var alarmTriggered = false

        let config = Storage.shared.alarmConfiguration.value

        // Honor the "Snooze All" setting. If active, stop any current alarm and exit.
        if let snoozeUntil = config.snoozeUntil, snoozeUntil > now {
            if Observable.shared.currentAlarm.value != nil {
                stopAlarm()
            }
            return
        }

        let alarms = Storage.shared.alarms.value

        let sorted = alarms.sorted(by: Alarm.byPriorityThenSpec)
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

            // If an alarm is BG-based, it usually requires recent data.
            // We make a specific exception for .missedReading, whose entire
            // purpose is to fire when recent BG data is NOT recent.
            if alarm.type.isBGBased, alarm.type != .missedReading, !isLatestReadingRecent {
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
                    LogManager.shared.log(category: .alarm, message: "Stopping alarm \(alarm) because it no longer meets its requirements", isDebug: true)

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

            if alarm.type == .temporary {
                // turn it off and persist
                var list = Storage.shared.alarms.value
                if let idx = list.firstIndex(where: { $0.id == alarm.id }) {
                    list[idx].isEnabled = false
                    list[idx].snoozedUntil = nil
                    Storage.shared.alarms.value = list
                }
            }

            alarmTriggered = true
            break
        }

        if isLatestReadingRecent, Storage.shared.persistentNotification.value, !alarmTriggered, let latestDate = data.bgReadings.last?.date, latestDate > Storage.shared.persistentNotificationLastBGTime.value {
            sendNotification(title: "Latest BG")
            Storage.shared.persistentNotificationLastBGTime.value = now
        }
    }

    func performSnooze(_ snoozeUnits: Int? = nil) {
        guard let alarmID = Observable.shared.currentAlarm.value else { return }
        var alarms = Storage.shared.alarms.value
        if let idx = alarms.firstIndex(where: { $0.id == alarmID }) {
            let alarm = alarms[idx]
            let units = snoozeUnits ?? alarm.snoozeDuration
            if units > 0 {
                let snoozeSeconds = Double(units) * alarm.type.snoozeTimeUnit.seconds
                alarms[idx].snoozedUntil = Date().addingTimeInterval(snoozeSeconds)
                Storage.shared.alarms.value = alarms
            }
            Observable.shared.alarmSoundPlaying.value = false
            stopAlarm()
        }
    }

    func stopAlarm() {
        AlarmSound.stop()
        Observable.shared.currentAlarm.value = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func sendNotification(title: String, actionTitle: String? = nil) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle += Observable.shared.bgText.value + " "
        content.subtitle += Observable.shared.directionText.value + " "
        content.subtitle += Observable.shared.deltaText.value
        content.categoryIdentifier = "category"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        if let actionTitle = actionTitle {
            let action = UNNotificationAction(identifier: "snooze", title: actionTitle, options: [])
            let category = UNNotificationCategory(identifier: "category", actions: [action], intentIdentifiers: [], options: [])
            UNUserNotificationCenter.current().setNotificationCategories([category])
        }
    }
}
