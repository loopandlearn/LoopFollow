// LoopFollow
// AlarmIntents.swift

import AppIntents
import Foundation

enum SnoozeDuration: String, AppEnum {
    case thirtyMinutes, oneHour, twoHours, fourHours, eightHours, twelveHours

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Snooze Duration")

    static var caseDisplayRepresentations: [SnoozeDuration: DisplayRepresentation] = [
        .thirtyMinutes: DisplayRepresentation(title: "30 minutes", synonyms: ["half an hour"]),
        .oneHour: DisplayRepresentation(title: "1 hour", synonyms: ["an hour", "one hour"]),
        .twoHours: DisplayRepresentation(title: "2 hours", synonyms: ["two hours"]),
        .fourHours: DisplayRepresentation(title: "4 hours", synonyms: ["four hours"]),
        .eightHours: DisplayRepresentation(title: "8 hours", synonyms: ["eight hours"]),
        .twelveHours: DisplayRepresentation(title: "12 hours", synonyms: ["twelve hours"]),
    ]

    var seconds: TimeInterval {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        }
    }
}

struct SnoozeAllAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze All Alarms"
    static var description = IntentDescription("Silences every LoopFollow alarm for the chosen time, like the Snooze All button in the app.")

    @Parameter(title: "Duration", default: .oneHour)
    var duration: SnoozeDuration

    static var parameterSummary: some ParameterSummary {
        Summary("Snooze all alarms for \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try IntentDataSource.ensureStorageAvailable()
        if Observable.shared.currentAlarm.value != nil {
            AlarmManager.shared.performSnooze()
        }
        let until = Date().addingTimeInterval(duration.seconds)
        Storage.shared.alarmConfiguration.value.snoozeUntil = until
        return .result(dialog: "All alarms are snoozed until \(SpokenDuration.clockTime(until)).")
    }
}

struct EndSnoozeIntent: AppIntent {
    static var title: LocalizedStringResource = "End Snooze"
    static var description = IntentDescription("Ends an active Snooze All so LoopFollow alarms can sound again.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try IntentDataSource.ensureStorageAvailable()
        let wasActive = (Storage.shared.alarmConfiguration.value.snoozeUntil ?? .distantPast) > Date()
        Storage.shared.alarmConfiguration.value.snoozeUntil = nil
        return .result(dialog: wasActive ? "Alarms are active again." : "No snooze was active.")
    }
}

struct MuteAlarmSoundsIntent: AppIntent {
    static var title: LocalizedStringResource = "Mute Alarm Sounds"
    static var description = IntentDescription("Mutes LoopFollow alarm sounds for the chosen time. Notifications and vibration continue.")

    @Parameter(title: "Duration", default: .oneHour)
    var duration: SnoozeDuration

    static var parameterSummary: some ParameterSummary {
        Summary("Mute alarm sounds for \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try IntentDataSource.ensureStorageAvailable()
        let until = Date().addingTimeInterval(duration.seconds)
        Storage.shared.alarmConfiguration.value.muteUntil = until
        return .result(dialog: "Alarm sounds are muted until \(SpokenDuration.clockTime(until)). Notifications and vibration continue.")
    }
}

struct UnmuteAlarmSoundsIntent: AppIntent {
    static var title: LocalizedStringResource = "Unmute Alarm Sounds"
    static var description = IntentDescription("Ends an active mute so LoopFollow alarms play sound again.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try IntentDataSource.ensureStorageAvailable()
        let wasActive = (Storage.shared.alarmConfiguration.value.muteUntil ?? .distantPast) > Date()
        Storage.shared.alarmConfiguration.value.muteUntil = nil
        return .result(dialog: wasActive ? "Alarm sounds are on again." : "Alarm sounds were not muted.")
    }
}

struct SnoozeCurrentAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Current Alarm"
    static var description = IntentDescription("Snoozes the alarm that is sounding right now, using that alarm's own snooze duration.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try IntentDataSource.ensureStorageAvailable()
        guard let alarm = IntentDataSource.soundingAlarm() else {
            return .result(dialog: "No alarm is sounding.")
        }
        let seconds = Double(alarm.snoozeDuration) * alarm.type.snoozeTimeUnit.seconds
        AlarmManager.shared.performSnooze()
        if seconds > 0 {
            return .result(dialog: "\(alarm.name) is snoozed for \(SpokenDuration.duration(seconds)).")
        }
        return .result(dialog: "\(alarm.name) is acknowledged.")
    }
}

struct GetAlarmStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Alarm Status"
    static var description = IntentDescription("Tells you whether LoopFollow alarms are snoozed or muted, and whether one is sounding.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        try IntentDataSource.ensureStorageAvailable()
        let input = StatusReadoutInput(
            snapshot: nil,
            lastLoopTime: 0,
            loopAppName: "",
            hasNightscout: false,
            alarms: IntentDataSource.alarmState(),
            now: Date()
        )
        let text = StatusReadoutFormatter.alarmSentence(input)
        return .result(value: text, dialog: IntentDialog("\(text)"))
    }
}
