// LoopFollow
// LocalizationEnumNameTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct LocalizationEnumNameTests {
    private static func turkish() throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: "tr", ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    private static func hasTurkish(_ bundle: Bundle, _ key: String) -> Bool {
        let v = bundle.localizedString(forKey: key, value: "MISSING", table: nil)
        return v != "MISSING" && !v.isEmpty
    }

    @Test("persisted raw values of enums touched by this PR are unchanged")
    func persistedRawValuesUnchanged() {
        #expect(ContactColorMode.staticColor.rawValue == "Static")
        #expect(ContactColorMode.dynamic.rawValue == "Dynamic")
        #expect(TRCCommandType.cancelOverride.rawValue == "cancel_override")
        #expect(TRCCommandType.tempTarget.rawValue == "temp_target")
        #expect(InfoType.iob.rawValue == 0)
        #expect(InfoType.dbSize.rawValue == InfoType.allCases.count - 1)
    }

    @Test("every enum display name has a Turkish value in the compiled bundle")
    func enumNamesHaveTurkish() throws {
        let tr = try Self.turkish()
        let keys = [
            "Static", "Dynamic (BG Range)", // ContactColorMode
            "System", "Light", "Dark", // AppearanceMode
            "Cone", "Lines", // PredictionDisplayType
            "Bolus", "Temp Target", "Cancel Temp Target", "Meal", "Start Override", "Cancel Override", // TRCCommandType
            "Carbs", "Automatic", "SMB", "Basal", "Override", // TreatmentType
            "Excellent", "Good", "Fair", "Poor", // DataAvailability
            "min", "hours", "days", "none", // AlarmType.timeUnit
            "Tab 1", "Tab 2", "Tab 3", "Tab 4", "Menu", // TabPosition
            "Home", "Alarms", "Remote", "Nightscout", "Snoozer", "Treatments", "Statistics", // TabItem
            "Basal", "Battery", "Pump", "Pump Battery", "SAGE", "CAGE", "Rec. Bolus", "Min/Max", "Carbs today", "Autosens", "Profile", "Target", "ISF", "CR", "Updated", "TDD", "IAGE", "DB Size", // InfoType
            "Custom Sound",
        ]
        let missing = keys.filter { !Self.hasTurkish(tr, $0) }
        #expect(missing.isEmpty, Comment(rawValue: "No Turkish for: " + missing.joined(separator: ", ")))
    }

    @Test("alarm blurbs resolve through the catalog")
    func alarmBlurbsHaveTurkish() throws {
        let tr = try Self.turkish()
        for type in AlarmType.allCases {
            #expect(!type.blurb.isEmpty)
        }
        #expect(Self.hasTurkish(tr, "Alerts when BG goes below a limit."))
        #expect(Self.hasTurkish(tr, "Alerts when BG rises above a limit."))
    }

    @Test("settings search leaves are localized")
    func settingsLeafTitlesAreLocalized() throws {
        let tr = try Self.turkish()
        let leaf = SettingsLeaf("Access Token", ["token"])
        #expect(leaf.title == Bundle.main.localizedString(forKey: "Access Token", value: nil, table: nil))
        #expect(Self.hasTurkish(tr, "Access Token"))
        #expect(Self.hasTurkish(tr, "Information Display"))
        #expect(Self.hasTurkish(tr, "Background Refresh"))
    }
}
