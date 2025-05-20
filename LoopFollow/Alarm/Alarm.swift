// LoopFollow
// Alarm.swift
// Created by Jonas Björkert on 2025-04-26.

import Foundation
import HealthKit
import UserNotifications

protocol DayNightDisplayable {
    var displayName: String { get }
}

extension DayNightDisplayable where Self: RawRepresentable, Self.RawValue == String {
    var displayName: String {
        rawValue == "always" ? "Day & Night" : rawValue.capitalized
    }
}

enum PlaySoundOption: String, CaseIterable, Codable, DayNightDisplayable {
    case always, day, night, never
}

enum RepeatSoundOption: String, CaseIterable, Codable, DayNightDisplayable {
    case always, day, night, never
}

enum ActiveOption: String, CaseIterable, Codable, DayNightDisplayable {
    case always, day, night
}

extension PlaySoundOption {
    static func allowed(for active: ActiveOption) -> [PlaySoundOption] {
        switch active {
        case .always: return PlaySoundOption.allCases
        case .day: return [.day, .never]
        case .night: return [.night, .never]
        }
    }
}

extension RepeatSoundOption {
    static func allowed(for active: ActiveOption) -> [RepeatSoundOption] {
        switch active {
        case .always: return RepeatSoundOption.allCases
        case .day: return [.day, .never]
        case .night: return [.night, .never]
        }
    }
}

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var type: AlarmType

    /// Name of the alarm, defaults to alarm type
    var name: String

    var isEnabled: Bool = true

    /// If the alarm is manually snoozed, we store the end time for the snooze here
    var snoozedUntil: Date?

    /// BG alarm threasholds
    var aboveBG: Double?
    var belowBG: Double?

    /// Alarm threashold, it can be a day for example
    var threshold: Double?

    /// If the alarm looks at predictions, this is how long into the future to look
    var predictiveMinutes: Int?

    /// If the alarm acts on delta, the delta is stored here, it can be a delta bgvalue (in mg/Dl)
    /// If a delta alarm is only active below a bg, that bg is stored in threshold
    var delta: Double?

    /// Number of minutes that must satisfy the alarm criteria
    var persistentMinutes: Int?

    /// Size of window to observe values, for example battery drop of x within this number of minutes,
    var monitoringWindow: Int?

    var soundFile: SoundFile

    /// Snooze duration, it can be minutes, days or hours. Stepping is different per alarm type
    var snoozeDuration: Int = 5

    /// When the alarm should play it's sound
    var playSoundOption: PlaySoundOption = .always

    /// When the sound should repeat
    var repeatSoundOption: RepeatSoundOption = .always

    /// When is the alarm active
    var activeOption: ActiveOption = .always

    /// For temporary alerts, it will trigger once and then disable itself
    var disableAfterFiring: Bool = false

    // ─────────────────────────────────────────────────────────────
    //  Missed‑Bolus‑specific settings
    // ─────────────────────────────────────────────────────────────

    /// “Prebolus Max Time” (if a bolus comes within this many minutes *before* the carbs, treat it as prebolus)
    var missedBolusPrebolusWindow: Int?

    /// “Ignore Bolus <= X units” (don’t count any bolus smaller than or equal to this)
    var missedBolusIgnoreSmallBolusUnits: Double?

    /// “Ignore Under Grams” (if carb entry is under this many grams, skip the alert)
    var missedBolusIgnoreUnderGrams: Double?

    /// “Ignore Under BG” (if current BG is below this, skip the alert)
    var missedBolusIgnoreUnderBG: Double?

    // ─────────────────────────────────────────────────────────────
    // Bolus‑Count fields ─
    // ─────────────────────────────────────────────────────────────
    /// trigger when N or more of those boluses occur...
    var bolusCountThreshold: Int?
    /// ...within this many minutes
    var bolusWindowMinutes: Int?

    /// Function for when the alarm is triggered.
    /// If this alarm, all alarms is disabled or snoozed, then should not be called. This or all alarmd could be muted, then this function will just generate a notification.
    func trigger(config: AlarmConfiguration, now: Date) {
        LogManager.shared.log(category: .alarm, message: "Alarm triggered: \(type.rawValue)")

        var playSound = true

        // Global mute
        if let until = config.muteUntil, until > now {
            playSound = false
        }

        // Mute during calls
        if !config.audioDuringCalls && isOnPhoneCall() {
            playSound = false
        }

        // Mute this alarm day or night or always
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let dayStart = cal.date(bySettingHour: config.dayStart.hour,
                                minute: config.dayStart.minute,
                                second: 0,
                                of: today)!
        let nightStart = cal.date(bySettingHour: config.nightStart.hour,
                                  minute: config.nightStart.minute,
                                  second: 0,
                                  of: today)!

        let isNight: Bool
        if nightStart >= dayStart {
            isNight = (now >= nightStart) || (now < dayStart)
        } else {
            isNight = (now >= nightStart) && (now < dayStart)
        }
        let isDay = !isNight

        switch playSoundOption {
        case .always:
            break
        case .never:
            playSound = false
        case .day where !isDay:
            playSound = false
        case .night where !isNight:
            playSound = false
        default:
            break
        }

        let shouldRepeat: Bool = {
            switch repeatSoundOption {
            case .always: return true
            case .never: return false
            case .day: return isDay
            case .night: return isNight
            }
        }()

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = type.rawValue
        content.subtitle += Observable.shared.bgText.value + " "
        content.subtitle += Observable.shared.directionText.value + " "
        content.subtitle += Observable.shared.deltaText.value
        content.categoryIdentifier = "category"
        // This is needed to trigger vibrate on watch and phone
        // See if we can use .Critcal
        // See if we should use this method instead of direct sound player
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        let action = UNNotificationAction(identifier: "snooze", title: "Snooze", options: [])
        let category = UNNotificationCategory(identifier: "category", actions: [action], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])

        /* TODO: när vi gör bg alarm sätt timestamp/datum för denna readings tid så vi inte larmar på samma igen, se isBGBased
             if snooozedBGReadingTime != nil {
                 UserDefaultsRepository.snoozedBGReadingTime.value = snooozedBGReadingTime
             }
         */

        if playSound {
            AlarmSound.setSoundFile(str: soundFile.rawValue)
            AlarmSound.play(repeating: shouldRepeat)
        }
    }

    init(type: AlarmType) {
        self.type = type
        name = type.rawValue

        switch type {
        case .buildExpire:
            /// Alert 7 days before the build expires
            threshold = 7
            soundFile = .wrongAnswer
            snoozeDuration = 1
            repeatSoundOption = .always
        case .low:
            soundFile = .indeed
        case .iob:
            soundFile = .alertToneRingtone1
        case .cob:
            soundFile = .alertToneRingtone2
        case .high:
            soundFile = .timeHasCome
        case .fastDrop:
            soundFile = .bigClockTicking
        case .fastRise:
            soundFile = .cartoonFailStringsTrumpet
        case .missedReading:
            soundFile = .cartoonTipToeSneakyWalk
        case .notLooping:
            soundFile = .sciFiEngineShutDown
        case .missedBolus:
            soundFile = .dholShuffleloop
        case .sensorChange:
            soundFile = .wakeUpWillYou
        case .pumpChange:
            soundFile = .wakeUpWillYou
        case .pump:
            soundFile = .marimbaDescend
        case .battery:
            soundFile = .machineCharge
        case .batteryDrop:
            soundFile = .machineCharge
        case .recBolus:
            soundFile = .dholShuffleloop
        case .overrideStart:
            soundFile = .endingReached
            repeatSoundOption = .never
        case .overrideEnd:
            soundFile = .alertToneBusy
            repeatSoundOption = .never
        case .tempTargetStart:
            soundFile = .endingReached
            repeatSoundOption = .never
        case .tempTargetEnd:
            soundFile = .alertToneBusy
            repeatSoundOption = .never
        case .temporary:
            soundFile = .indeed
        }
    }
}

extension AlarmType {
    enum Group: String, CaseIterable {
        case glucose = "Glucose"
        case insulin = "Insulin / Food"
        case device = "Device / System"
        case other = "Override / Target"
    }

    var group: Group {
        switch self {
        case .low, .high, .fastDrop, .fastRise, .missedReading, .temporary:
            return .glucose
        case .iob, .cob, .missedBolus, .recBolus:
            return .insulin
        case .battery, .batteryDrop, .pump, .pumpChange,
             .sensorChange, .notLooping, .buildExpire:
            return .device
        case .overrideStart, .overrideEnd, .tempTargetStart, .tempTargetEnd:
            return .other
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down.to.line"
        case .high: return "arrow.up.to.line"
        case .fastDrop: return "chevron.down.2"
        case .fastRise: return "chevron.up.2"
        case .missedReading: return "wifi.slash"
        case .iob: return "syringe"
        case .cob: return "fork.knife"
        case .missedBolus: return "exclamationmark.arrow.triangle.2.circlepath"
        case .recBolus: return "bolt.horizontal"
        case .battery: return "battery.25"
        case .batteryDrop: return "battery.100.bolt"
        case .pump: return "drop"
        case .pumpChange: return "arrow.triangle.2.circlepath"
        case .sensorChange: return "sensor.tag.radiowaves.forward"
        case .notLooping: return "circle.slash"
        case .buildExpire: return "calendar.badge.exclamationmark"
        case .overrideStart: return "play.circle"
        case .overrideEnd: return "stop.circle"
        case .tempTargetStart: return "flag"
        case .tempTargetEnd: return "flag.slash"
        case .temporary: return "bell"
        }
    }

    var blurb: String {
        switch self {
        case .low: return "Alerts when BG goes below a limit."
        case .high: return "Alerts when BG rises above a limit."
        case .fastDrop: return "Rapid downward BG trend."
        case .fastRise: return "Rapid upward BG trend."
        case .missedReading: return "No CGM data for X minutes."
        case .iob: return "High insulin-on-board."
        case .cob: return "High carbs-on-board."
        case .missedBolus: return "Carbs without bolus."
        case .recBolus: return "Recommended bolus issued."
        case .battery: return "Phone battery low."
        case .batteryDrop: return "Battery drops quickly."
        case .pump: return "Reservoir level low."
        case .pumpChange: return "Pump change due."
        case .sensorChange: return "Sensor change due."
        case .notLooping: return "Loop hasn’t completed."
        case .buildExpire: return "Looping-app build expiring."
        case .overrideStart: return "Override just started."
        case .overrideEnd: return "Override ended."
        case .tempTargetStart: return "Temp target started."
        case .tempTargetEnd: return "Temp target ended."
        case .temporary: return "One-time BG limit alert."
        }
    }
}
