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

    /// The test host runs in whatever language the simulator uses, so compare against the
    /// catalog lookup for the same key instead of hardcoding English.
    private func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    @Test("AlarmType.displayName resolves its raw value through the String Catalog")
    func alarmTypeDisplayNameUsesCatalog() {
        for type in AlarmType.allCases {
            #expect(type.displayName == localized(type.rawValue))
            #expect(!type.displayName.isEmpty)
        }
    }

    @Test("day/night displayName resolves its English key through the String Catalog")
    func dayNightDisplayNameUsesCatalog() {
        #expect(PlaySoundOption.always.displayName == localized("Day & Night"))
        #expect(PlaySoundOption.day.displayName == localized("Day"))
        #expect(PlaySoundOption.night.displayName == localized("Night"))
        #expect(PlaySoundOption.never.displayName == localized("Never"))
        #expect(ActiveOption.always.displayName == localized("Day & Night"))
    }

    @Test("Turkish strings are compiled into the app bundle")
    func turkishBundleContainsAlarmTypeNames() throws {
        let path = try #require(Bundle.main.path(forResource: "tr", ofType: "lproj"), "tr.lproj missing: check knownRegions and catalog target membership")
        let bundle = try #require(Bundle(path: path))
        for type in AlarmType.allCases {
            let localized = bundle.localizedString(forKey: type.rawValue, value: "MISSING", table: nil)
            #expect(localized != "MISSING", Comment(rawValue: "no Turkish value for \(type.rawValue)"))
            #expect(localized != type.rawValue, Comment(rawValue: "Turkish value equals English for \(type.rawValue)"))
        }
        #expect(bundle.localizedString(forKey: "Day & Night", value: "MISSING", table: nil) == "Gündüz ve Gece")
    }

    @Test("English plural variation resolves through the compiled catalog")
    func englishPluralVariationApplies() throws {
        let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let one = String(localized: "Calculated \(1) minutes ago", bundle: bundle)
        let many = String(localized: "Calculated \(5) minutes ago", bundle: bundle)
        #expect(one == "Calculated 1 minute ago")
        #expect(many == "Calculated 5 minutes ago")
    }

    @Test("main screen status strings have Turkish values and keep their argument")
    func minAgoFormatIsLocalized() throws {
        let path = try #require(Bundle.main.path(forResource: "tr", ofType: "lproj"))
        let tr = try #require(Bundle(path: path))
        for key in ["%@ min ago", "%lld min", "LOW", "HIGH", "⚠️ Not Looping!", "Refreshing", "Loading...", "Setup Nightscout", "Setup Dexcom Share", "%llds left",
                    "Number of hours before the %lld-day mark that the alert will fire.", "BG Check", "Sensor Start", "Update Available"]
        {
            let v = tr.localizedString(forKey: key, value: "MISSING", table: nil)
            #expect(v != "MISSING", Comment(rawValue: "no Turkish for \(key)"))
        }
        let minAgo = String(format: tr.localizedString(forKey: "%lld min", value: nil, table: nil), 7)
        #expect(minAgo.contains("7"))
        // The main screen shows a formatted duration such as "4:35", so its key takes a string argument.
        let mainScreen = String(format: tr.localizedString(forKey: "%@ min ago", value: nil, table: nil), "4:35")
        #expect(mainScreen.contains("4:35"))
    }

    @Test("Nightscout 'checking' state is detected in any language")
    @MainActor
    func nightscoutCheckingStateIsLanguageIndependent() {
        let vm = NightscoutSettingsViewModel()
        vm.nightscoutURL = "https://example.invalid"
        vm.nightscoutStatus = String(localized: "Checking...")
        #expect(vm.statusKind == .checking)
    }
}
