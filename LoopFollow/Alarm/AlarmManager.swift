// LoopFollow
// AlarmManager.swift

import Foundation
import UserNotifications

class AlarmManager {
    static let shared = AlarmManager()

    private let evaluators: [AlarmType: AlarmCondition]
    private var lastBGAlarmTime: Date?

    /// When each alarm last fired and with what title, for the CarPlay
    /// widget's event alarms.
    private var lastFired: [UUID: (title: String, date: Date)] = [:]

    /// How long the CarPlay widget lists an alarm that announces an event,
    /// such as an override starting, after it fires.
    static let carPlayEventDuration: TimeInterval = 15 * 60

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
            PumpBatteryCondition.self,
            IOBCondition.self,
            BatteryCondition.self,
            BatteryDropCondition.self,
            FutureCarbsCondition.self,
            MissedBolusCondition.self,
            DBSizeCondition.self,
        ]
    ) {
        var dict = [AlarmType: AlarmCondition]()
        conditionTypes.forEach { dict[$0.type] = $0.init() }
        evaluators = dict
    }

    func checkAlarms(data: AlarmData) {
        let now = Date()
        var alarmTriggered = false

        // No alarm activity while onboarding is on screen — existing or
        // QR-imported alarms shouldn't sound mid-setup.
        if Observable.shared.isOnboardingActive.value {
            if Observable.shared.currentAlarm.value != nil {
                stopAlarm()
            }
            return
        }

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

            let titleOverride = checker.firedTitle

            // An active alarm that still fulfills the requirements stays active.
            // A different phase of it (an end alarm's early warning followed
            // by the end itself) is announced with its own title.
            if Observable.shared.currentAlarm.value == alarm.id {
                if titleOverride != Observable.shared.currentAlarmTitleOverride.value {
                    Observable.shared.currentAlarmTitleOverride.value = titleOverride
                    alarm.trigger(config: Storage.shared.alarmConfiguration.value, now: now, titleOverride: titleOverride)
                    lastFired[alarm.id] = (titleOverride ?? alarm.name, now)
                }
                break
            }

            // Fire the alarm and break the loop; we only allow one alarm per evaluation tick.
            Observable.shared.currentAlarmTitleOverride.value = titleOverride
            Observable.shared.currentAlarm.value = alarm.id

            alarm.trigger(config: Storage.shared.alarmConfiguration.value, now: now, titleOverride: titleOverride)
            lastFired[alarm.id] = (titleOverride ?? alarm.name, now)

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

    /// The alarms the CarPlay widget shows: each enabled alarm marked for
    /// CarPlay that is triggered now, the first of each type, most important
    /// first, with the title to show. Snoozed alarms count.
    ///
    /// Alarms about a state (low BG, carbs on board over the threshold, a
    /// sensor about to expire) are listed while the state holds, checked
    /// without the side effects of the alarm's own check. Alarms about an
    /// event (an override starting, a missed bolus) are listed for
    /// `carPlayEventDuration` after they fire. Whatever is sounding is listed.
    func carPlayAlarms(data: AlarmData, now: Date) -> [(alarm: Alarm, title: String)] {
        let config = Storage.shared.alarmConfiguration.value
        let sounding = Observable.shared.currentAlarm.value
        lastFired = lastFired.filter { now.timeIntervalSince($0.value.date) < Self.carPlayEventDuration }

        // Between readings the latest is up to 5 minutes old; allow until it
        // is stale so BG alerts don't flicker off while waiting for the next.
        let readingIsCurrent = data.bgReadings.last.map {
            now.timeIntervalSince($0.date) < GlucoseSnapshot.staleAfter
        } ?? false

        var result: [(alarm: Alarm, title: String)] = []
        var listedTypes = Set<AlarmType>()

        for alarm in Storage.shared.alarms.value.sorted(by: Alarm.byPriorityThenSpec) {
            guard alarm.showInCarPlay, !listedTypes.contains(alarm.type) else { continue }

            var title: String?
            if alarm.id == sounding {
                // A temporary alarm disables itself as it fires, so this
                // comes before the check that the alarm is on.
                title = Observable.shared.currentAlarmTitleOverride.value ?? alarm.name
            } else if alarm.isEnabled, let checker = evaluators[alarm.type] {
                if alarm.type.isBGBased, alarm.type != .missedReading, !readingIsCurrent { continue }
                var unsnoozed = alarm
                unsnoozed.snoozedUntil = nil

                if let holds = checker.holds(alarm: unsnoozed, data: data, now: now) {
                    if holds, checker.passesGuards(alarm: unsnoozed, data: data, now: now, config: config) {
                        title = alarm.name
                    }
                } else {
                    title = lastFired[alarm.id]?.title
                }
            }

            if let title {
                result.append((alarm, title))
                listedTypes.insert(alarm.type)
            }
        }
        return result
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
        Observable.shared.currentAlarmTitleOverride.value = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func sendNotification(title: String, body: String? = nil, actionTitle: String? = nil) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle += Observable.shared.bgText.value + " "
        content.subtitle += Observable.shared.directionText.value + " "
        content.subtitle += Observable.shared.deltaText.value
        if let body {
            content.body = body
        }
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
