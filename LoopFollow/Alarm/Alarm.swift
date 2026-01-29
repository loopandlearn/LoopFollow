// LoopFollow
// Alarm.swift

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

    /// Delay in seconds between repeated alarm sounds (0 = no delay, only applies when repeating)
    var soundDelay: Int = 0

    /// When is the alarm active
    var activeOption: ActiveOption = .always

    // MARK: - Codable (Custom implementation for backward compatibility)

    enum CodingKeys: String, CodingKey {
        case id, type, name, isEnabled, snoozedUntil
        case aboveBG, belowBG, threshold, predictiveMinutes, delta
        case persistentMinutes, monitoringWindow, soundFile
        case snoozeDuration, playSoundOption, repeatSoundOption
        case soundDelay, activeOption
        case missedBolusPrebolusWindow, missedBolusIgnoreSmallBolusUnits
        case missedBolusIgnoreUnderGrams, missedBolusIgnoreUnderBG
        case bolusCountThreshold, bolusWindowMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(AlarmType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        aboveBG = try container.decodeIfPresent(Double.self, forKey: .aboveBG)
        belowBG = try container.decodeIfPresent(Double.self, forKey: .belowBG)
        threshold = try container.decodeIfPresent(Double.self, forKey: .threshold)
        predictiveMinutes = try container.decodeIfPresent(Int.self, forKey: .predictiveMinutes)
        delta = try container.decodeIfPresent(Double.self, forKey: .delta)
        persistentMinutes = try container.decodeIfPresent(Int.self, forKey: .persistentMinutes)
        monitoringWindow = try container.decodeIfPresent(Int.self, forKey: .monitoringWindow)
        soundFile = try container.decode(SoundFile.self, forKey: .soundFile)
        snoozeDuration = try container.decodeIfPresent(Int.self, forKey: .snoozeDuration) ?? 5
        playSoundOption = try container.decodeIfPresent(PlaySoundOption.self, forKey: .playSoundOption) ?? .always
        repeatSoundOption = try container.decodeIfPresent(RepeatSoundOption.self, forKey: .repeatSoundOption) ?? .always
        // Handle backward compatibility: default to 0 if soundDelay is missing
        soundDelay = try container.decodeIfPresent(Int.self, forKey: .soundDelay) ?? 0
        activeOption = try container.decodeIfPresent(ActiveOption.self, forKey: .activeOption) ?? .always
        missedBolusPrebolusWindow = try container.decodeIfPresent(Int.self, forKey: .missedBolusPrebolusWindow)
        missedBolusIgnoreSmallBolusUnits = try container.decodeIfPresent(Double.self, forKey: .missedBolusIgnoreSmallBolusUnits)
        missedBolusIgnoreUnderGrams = try container.decodeIfPresent(Double.self, forKey: .missedBolusIgnoreUnderGrams)
        missedBolusIgnoreUnderBG = try container.decodeIfPresent(Double.self, forKey: .missedBolusIgnoreUnderBG)
        bolusCountThreshold = try container.decodeIfPresent(Int.self, forKey: .bolusCountThreshold)
        bolusWindowMinutes = try container.decodeIfPresent(Int.self, forKey: .bolusWindowMinutes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(snoozedUntil, forKey: .snoozedUntil)
        try container.encodeIfPresent(aboveBG, forKey: .aboveBG)
        try container.encodeIfPresent(belowBG, forKey: .belowBG)
        try container.encodeIfPresent(threshold, forKey: .threshold)
        try container.encodeIfPresent(predictiveMinutes, forKey: .predictiveMinutes)
        try container.encodeIfPresent(delta, forKey: .delta)
        try container.encodeIfPresent(persistentMinutes, forKey: .persistentMinutes)
        try container.encodeIfPresent(monitoringWindow, forKey: .monitoringWindow)
        try container.encode(soundFile, forKey: .soundFile)
        try container.encode(snoozeDuration, forKey: .snoozeDuration)
        try container.encode(playSoundOption, forKey: .playSoundOption)
        try container.encode(repeatSoundOption, forKey: .repeatSoundOption)
        try container.encode(soundDelay, forKey: .soundDelay)
        try container.encode(activeOption, forKey: .activeOption)
        try container.encodeIfPresent(missedBolusPrebolusWindow, forKey: .missedBolusPrebolusWindow)
        try container.encodeIfPresent(missedBolusIgnoreSmallBolusUnits, forKey: .missedBolusIgnoreSmallBolusUnits)
        try container.encodeIfPresent(missedBolusIgnoreUnderGrams, forKey: .missedBolusIgnoreUnderGrams)
        try container.encodeIfPresent(missedBolusIgnoreUnderBG, forKey: .missedBolusIgnoreUnderBG)
        try container.encodeIfPresent(bolusCountThreshold, forKey: .bolusCountThreshold)
        try container.encodeIfPresent(bolusWindowMinutes, forKey: .bolusWindowMinutes)
    }

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

    /// ─────────────────────────────────────────────────────────────
    /// Bolus‑Count fields ─
    /// ─────────────────────────────────────────────────────────────
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
        if !config.audioDuringCalls, isOnPhoneCall() {
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

        AlarmManager.shared.sendNotification(title: type.rawValue, actionTitle: snoozeDuration == 0 ? "Acknowledge" : "Snooze")

        if playSound {
            AlarmSound.setSoundFile(str: soundFile.rawValue)
            // Only use delay if repeating is enabled, otherwise delay doesn't make sense
            let delay = shouldRepeat ? soundDelay : 0
            AlarmSound.play(repeating: shouldRepeat, delay: delay)
        }
    }

    init(type: AlarmType) {
        self.type = type
        name = type.rawValue

        switch type {
        case .buildExpire:
            // Alert 7 days before the build expires
            threshold = 7
            soundFile = .wrongAnswer
            snoozeDuration = 1
            repeatSoundOption = .always
        case .low:
            soundFile = .indeed
            belowBG = 80
            persistentMinutes = 0
            predictiveMinutes = 0
        case .iob:
            soundFile = .alertToneRingtone1
            delta = 1
            monitoringWindow = 2
            predictiveMinutes = 30
            threshold = 6
        case .cob:
            soundFile = .alertToneRingtone2
            threshold = 20
        case .high:
            soundFile = .timeHasCome
            aboveBG = 180
            persistentMinutes = 0
        case .fastDrop:
            soundFile = .bigClockTicking
            delta = 18
            monitoringWindow = 2
        case .fastRise:
            soundFile = .cartoonFailStringsTrumpet
            delta = 10
            monitoringWindow = 3
        case .missedReading:
            soundFile = .cartoonTipToeSneakyWalk
            threshold = 16
        case .notLooping:
            soundFile = .sciFiEngineShutDown
            threshold = 31
        case .missedBolus:
            soundFile = .dholShuffleloop
            monitoringWindow = 15
            predictiveMinutes = 15
            delta = 0.1
            threshold = 4
        case .sensorChange:
            soundFile = .wakeUpWillYou
            threshold = 12
        case .pumpChange:
            soundFile = .wakeUpWillYou
            threshold = 12
        case .pump:
            soundFile = .marimbaDescend
            threshold = 20
        case .pumpBattery:
            soundFile = .machineCharge
            threshold = 20
        case .battery:
            soundFile = .machineCharge
            threshold = 20
        case .batteryDrop:
            soundFile = .machineCharge
            delta = 10
            monitoringWindow = 15
        case .recBolus:
            soundFile = .dholShuffleloop
            threshold = 1
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
            snoozeDuration = 0
            aboveBG = 180
            belowBG = 70
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
        case .battery, .batteryDrop, .pump, .pumpBattery, .pumpChange,
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
        case .pumpBattery: return "powermeter"
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
        case .pumpBattery: return "Pump battery low."
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
