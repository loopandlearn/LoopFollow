// LoopFollow
// LocalizationDisplayNameTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct LocalizationDisplayNameTests {
    /// Persisted raw values. Changing any of these breaks decoding of stored alarms.
    private static let alarmTypeRawValues: [AlarmType: String] = [
        .temporary: "Temporary Alert",
        .iob: "IOB Alert",
        .cob: "COB Alert",
        .low: "Low BG Alert",
        .high: "High BG Alert",
        .fastDrop: "Fast Drop Alert",
        .fastRise: "Fast Rise Alert",
        .missedReading: "Missed Reading Alert",
        .notLooping: "Not Looping Alert",
        .missedBolus: "Missed Bolus Alert",
        .futureCarbs: "Future Carbs Alert",
        .sensorChange: "Sensor Change Alert",
        .pumpChange: "Pump Change Alert",
        .pump: "Pump Insulin Alert",
        .pumpBattery: "Pump Battery Alert",
        .battery: "Low Battery",
        .batteryDrop: "Battery Drop",
        .recBolus: "Rec. Bolus",
        .overrideStart: "Override Started",
        .overrideEnd: "Override Ended",
        .tempTargetStart: "Temp Target Started",
        .tempTargetEnd: "Temp Target Ended",
        .buildExpire: "Looping app expiration",
        .dbSize: "Nightscout Database Size",
    ]

    @Test("AlarmType raw values are stable (they are persisted)")
    func alarmTypeRawValuesAreStable() {
        #expect(AlarmType.allCases.count == Self.alarmTypeRawValues.count)
        for (type, raw) in Self.alarmTypeRawValues {
            #expect(type.rawValue == raw)
        }
    }

    @Test("day/night option raw values are stable (they are persisted)")
    func dayNightRawValuesAreStable() {
        #expect(PlaySoundOption.allCases.map(\.rawValue) == ["always", "day", "night", "never"])
        #expect(RepeatSoundOption.allCases.map(\.rawValue) == ["always", "day", "night", "never"])
        #expect(ActiveOption.allCases.map(\.rawValue) == ["always", "day", "night"])
    }

    @Test("AlarmType.displayName falls back to the English raw value in the test host language")
    func alarmTypeDisplayNameEnglish() {
        for type in AlarmType.allCases {
            #expect(type.displayName == type.rawValue)
        }
    }

    @Test("day/night displayName keeps the English wording")
    func dayNightDisplayNameEnglish() {
        #expect(PlaySoundOption.always.displayName == "Day & Night")
        #expect(PlaySoundOption.day.displayName == "Day")
        #expect(PlaySoundOption.night.displayName == "Night")
        #expect(PlaySoundOption.never.displayName == "Never")
        #expect(ActiveOption.always.displayName == "Day & Night")
    }
}
