// LoopFollow
// AlarmConfiguration.swift

import Foundation

struct AlarmConfiguration: Codable, Equatable {
    // MARK: Core

    var snoozeUntil: Date?
    var muteUntil: Date?
    var dayStart: TimeOfDay
    var nightStart: TimeOfDay

    // MARK: System audio overrides

    var overrideSystemOutputVolume: Bool
    var forcedOutputVolume: Float // 0 … 1
    var audioDuringCalls: Bool
    var ignoreZeroBG: Bool
    var autoSnoozeCGMStart: Bool
    var enableVolumeButtonSnooze: Bool

    static let `default` = AlarmConfiguration(
        muteUntil: nil,
        dayStart: TimeOfDay(hour: 6, minute: 0),
        nightStart: TimeOfDay(hour: 22, minute: 0),
        overrideSystemOutputVolume: true,
        forcedOutputVolume: 0.5,
        audioDuringCalls: true,
        ignoreZeroBG: true,
        autoSnoozeCGMStart: false,
        enableVolumeButtonSnooze: false
    )

    /// Night runs from `nightStart` up to the next `dayStart`, wrapping past midnight
    /// when `nightStart` is later in the day than `dayStart`.
    func isNight(at date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let now = comps.hour! * 60 + comps.minute!
        let day = dayStart.minutesSinceMidnight
        let night = nightStart.minutesSinceMidnight
        if night >= day {
            return now >= night || now < day
        }
        return now >= night && now < day
    }
}
