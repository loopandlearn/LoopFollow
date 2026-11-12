// LoopFollow
// TherapyProfileTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TherapyProfileTests {
    static func store(units: String, sens: Double, low: Double, high: Double, basal: [(Int, Double)] = [(0, 0.85), (21600, 1.1)]) throws -> NSProfile.Store {
        let basalJSON = basal.map { "{\"time\": \"x\", \"value\": \($0.1), \"timeAsSeconds\": \($0.0)}" }.joined(separator: ",")
        let json = """
        {"timezone": "ETC/GMT-1", "units": "\(units)",
         "basal": [\(basalJSON)],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": \(sens), "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": \(low), "timeAsSeconds": 0}],
         "target_high": [{"time": "00:00", "value": \(high), "timeAsSeconds": 0}]}
        """
        return try JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8))
    }

    static func document(_ store: [String: NSProfile.Store], active: String, limits: ProfileEditLimits? = nil) -> NSProfile {
        NSProfile(store: store, defaultProfile: active, units: "mg/dL",
                  bundleIdentifier: nil, isAPNSProduction: nil, deviceToken: nil, teamID: nil, expirationDate: nil,
                  startDate: nil, createdAt: nil, remoteCommands: nil, trioOverrides: nil, loopSettings: nil,
                  profileEditLimits: LenientDecoded(limits), scheduledSwitches: nil, scheduledSwitchesFingerprint: nil)
    }

    @Test("Loop lists its profile commands in its profile document")
    func loopProfileCommandsFromDocument() throws {
        let json = """
        {"defaultProfile": "Default", "units": "mg/dL", "store": {}, "enteredBy": "Loop",
         "remoteCommands": ["profile-switch", "profile-save", "profile-delete", "profile-scheduled-switches-save"]}
        """
        let document = try JSONDecoder().decode(NSProfile.self, from: Data(json.utf8))
        let commands = try #require(document.remoteCommands)
        for kind in ProfileCommandKind.allCases {
            #expect(ProfileRemote.loop.supports(kind, in: commands))
        }
        #expect(!ProfileRemote.trio.supportsAny(in: commands))
        #expect(!ProfileRemote.loop.supportsAny(in: []))
    }

    @Test("a Loop with the Profile Save & Load customization accepts switches it lists in its device status")
    func loopCustomizationSwitchFromDeviceStatus() {
        let commands = ProfileRemote.loop.acceptedCommands(profileDocument: [], loopDeviceStatus: ["carbs-delete", "profile-switch"])
        #expect(ProfileRemote.loop.supports(.activate, in: commands))
        #expect(!ProfileRemote.loop.supports(.save, in: commands))
        #expect(!ProfileRemote.loop.supports(.delete, in: commands))
        #expect(ProfileRemote.loop.acceptedCommands(profileDocument: [], loopDeviceStatus: []).isEmpty)
        #expect(ProfileRemote.trio.acceptedCommands(profileDocument: [], loopDeviceStatus: ["profile-switch"]).isEmpty)
        // A Loop that lists commands in both places is used through its profile document.
        let document = ["profile-switch", "profile-save", "profile-delete"]
        #expect(ProfileRemote.loop.acceptedCommands(profileDocument: document, loopDeviceStatus: ["profile-switch"]) == document)
        #expect(ProfileRemote.loop.acceptedCommands(profileDocument: ["profile-switch"], loopDeviceStatus: ["profile-switch"]) == ["profile-switch"])
    }

    @Test("a document saved by the Nightscout profile editor, whose entries have no units, still loads")
    func entriesWithoutUnitsUseTheDocumentUnits() throws {
        let json = """
        {"defaultProfile": "Weekend", "units": "mmol", "enteredBy": "Trio",
         "store": {
           "default": {"timezone": "Europe/Stockholm", "dia": 6, "startDate": "1970-01-01T00:00:00.000Z",
             "basal": [{"time": "00:00", "value": 1.0, "timeAsSeconds": 0}],
             "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
             "sens": [{"time": "00:00", "value": 2.5, "timeAsSeconds": 0}],
             "target_low": [{"time": "00:00", "value": 5.6, "timeAsSeconds": 0}],
             "target_high": [{"time": "00:00", "value": 5.6, "timeAsSeconds": 0}]},
           "Weekend": {"timezone": "Europe/Stockholm", "dia": 6, "units": "mmol", "delay": 20,
             "basal": [{"time": "00:00", "value": 1.1, "timeAsSeconds": 0}],
             "carbratio": [{"time": "00:00", "value": 11, "timeAsSeconds": 0}],
             "sens": [{"time": "00:00", "value": 3.1, "timeAsSeconds": 0}],
             "target_low": [{"time": "00:00", "value": 5.8, "timeAsSeconds": 0}],
             "target_high": [{"time": "00:00", "value": 5.8, "timeAsSeconds": 0}]}}}
        """
        let document = try JSONDecoder().decode(NSProfile.self, from: Data(json.utf8))
        let set = TherapyProfileSet(document)
        #expect(set.activeProfile?.name == "Weekend")
        #expect(set.profiles.map(\.values.units) == ["mmol/L", "mmol/L"])
    }

    @Test("a store entry that can not be read leaves the other profiles readable")
    func unreadableEntryIsLeftOut() throws {
        let json = """
        {"defaultProfile": "Default", "units": "mg/dL", "startDate": 1793527200000,
         "store": {
           "Default": {"timezone": "UTC", "units": "mg/dL",
             "basal": [{"time": "00:00", "value": 1.0, "timeAsSeconds": 0}],
             "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
             "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
             "target_low": [{"time": "00:00", "value": 100, "timeAsSeconds": 0}],
             "target_high": [{"time": "00:00", "value": 110, "timeAsSeconds": 0}]},
           "Broken": {"timezone": "UTC", "units": "mg/dL", "basal": [{"time": "00:00", "value": "1.0"}]}}}
        """
        let document = try JSONDecoder().decode(NSProfile.self, from: Data(json.utf8))
        #expect(document.store.keys.sorted() == ["Default"])
        #expect(document.startDate == nil)
    }

    @Test("the shared test vector gives the contract's canonical string and hash")
    func contractVector() throws {
        let basal = [ProfileScheduleItem(seconds: 0, value: 0.85), ProfileScheduleItem(seconds: 21600, value: 1.0)]
        let carbRatio = [ProfileScheduleItem(seconds: 0, value: 10)]
        let sens = [ProfileScheduleItem(seconds: 0, value: 50)]
        let canonical = TherapyProfileValues.canonicalString(
            basal: basal, carbRatio: carbRatio, sensitivity: sens,
            targetLow: [ProfileScheduleItem(seconds: 0, value: 100)], targetHigh: [ProfileScheduleItem(seconds: 0, value: 110)]
        )
        #expect(canonical == "basal=0:0.850,21600:1.000;carbratio=0:10.000;sens=0:50.000;target_low=0:100.000;target_high=0:110.000")
        let values = TherapyProfileValues(units: "mg/dL", basal: basal, carbRatio: carbRatio, sensitivity: sens, target: [ProfileRangeItem(seconds: 0, low: 100, high: 110)])
        #expect(values.fingerprint == "3e603478d512da04")
        let profile = try TherapyProfile(name: "Vector", store: Self.store(units: "mg/dL", sens: 50, low: 100, high: 110, basal: [(0, 0.85), (21600, 1.0)]))
        #expect(profile.fingerprint == "3e603478d512da04")
        #expect(profile.values.fingerprint == profile.fingerprint)
    }

    @Test("fingerprint matches the value Loop computes for the same store entry")
    func fingerprint() throws {
        let mgdl = try TherapyProfile(name: "Sport", store: Self.store(units: "mg/dL", sens: 45, low: 100, high: 110))
        #expect(mgdl.fingerprint == "fec4f066b5a54ecd")
        let mmol = try TherapyProfile(name: "Sport", store: Self.store(units: "mmol/L", sens: 2.497_646_904_752_9, low: 5.550_747_991_045_533, high: 6.105_822_790_150_087))
        #expect(mmol.fingerprint == "f7d9520ff02af97c")
        #expect(mmol.values.units == "mmol/L")
    }

    @Test("basal total weights each rate by how long it runs")
    func basalTotal() throws {
        let profile = try TherapyProfile(name: "Sport", store: Self.store(units: "mg/dL", sens: 45, low: 100, high: 110))
        #expect(abs(profile.basalTotal - (0.85 * 6 + 1.1 * 18)) < 0.000_1)
        #expect(profile.correctionRange == [ProfileRangeItem(seconds: 0, low: 100, high: 110)])
        #expect(profile.isWellFormed)
    }

    @Test("Default is listed first and is the active profile when defaultProfile names it in any case")
    func defaultProfile() throws {
        let entry = try Self.store(units: "mg/dL", sens: 45, low: 100, high: 110)
        let loop = TherapyProfileSet(Self.document(["Default": entry, "Work": entry, "Sport": entry], active: "Work"))
        #expect(loop.profiles.map(\.name) == ["Default", "Sport", "Work"])
        #expect(loop.activeName == "Work")
        #expect(loop.activeProfile?.name == "Work")
        #expect(loop.profiles[0].isDefault)

        let trio = TherapyProfileSet(Self.document(["default": entry, "school": entry], active: "default"))
        #expect(trio.profiles.map(\.name) == ["Default", "school"])
        #expect(trio.profiles[0].isDefault)
        #expect(trio.activeProfile?.name == "Default")
        #expect(TherapyProfile.isDefaultName("DEFAULT"))
        #expect(!TherapyProfile.isDefaultName("Defaults"))
    }

    @Test("a profile without a correction range is read-only")
    func missingRange() throws {
        let json = """
        {"timezone": "UTC", "units": "mg/dL",
         "basal": [{"time": "00:00", "value": 1, "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}]}
        """
        let profile = try TherapyProfile(name: "X", store: JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8)))
        #expect(!profile.isWellFormed)
        #expect(try ProfileEditing.blocker(for: profile, limits: ProfileEditLimitsTests.limits(), remote: .loop) != nil)
    }

    @Test("a profile in mmol/L can not be edited against limits in mg/dL")
    func unitMismatch() throws {
        let limits = try ProfileEditLimitsTests.limits()
        let mmol = try TherapyProfile(name: "Sport", store: Self.store(units: "mmol", sens: 2.5, low: 5.5, high: 6.1))
        let blocker = try #require(ProfileEditing.blocker(for: mmol, limits: limits, remote: .trio))
        #expect(blocker.contains("mmol/L"))
        let mgdl = try TherapyProfile(name: "Sport", store: Self.store(units: "mg/dL", sens: 45, low: 100, high: 110))
        #expect(ProfileEditing.blocker(for: mgdl, limits: limits, remote: .trio) == nil)
    }

    @Test("mismatched correction range lows and highs make the profile read-only")
    func malformedRange() throws {
        let json = """
        {"timezone": "UTC", "units": "mg/dl",
         "basal": [{"time": "00:00", "value": 1, "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": 100, "timeAsSeconds": 0}, {"time": "06:00", "value": 90, "timeAsSeconds": 21600}],
         "target_high": [{"time": "00:00", "value": 110, "timeAsSeconds": 0}]}
        """
        let store = try JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8))
        let profile = TherapyProfile(name: "X", store: store)
        #expect(!profile.isWellFormed)
        #expect(profile.values.units == "mg/dL")
        let limits = try ProfileEditLimitsTests.limits()
        #expect(ProfileEditing.blocker(for: profile, limits: limits, remote: .loop) != nil)
    }

    @Test("follow-up fetches after a profile command stop once its result is in the profile document")
    func profileCommandArrival() throws {
        let base = try Self.store(units: "mg/dL", sens: 45, low: 100, high: 110)
        let changed = try Self.store(units: "mg/dL", sens: 50, low: 100, high: 110)
        let before = TherapyProfileSet(Self.document(["Default": base, "Sport": base], active: "Default"))
        let sport = try #require(before.profile(named: "Sport"))
        func arrived(_ command: ProfileCommand, _ now: [String: NSProfile.Store], active: String = "Default") -> Bool {
            RemoteCommandRefresh.profileArrived(command, before: before, now: TherapyProfileSet(Self.document(now, active: active)))
        }

        #expect(!RemoteCommandRefresh.profileArrived(.activate(sport), before: before, now: nil))
        #expect(!arrived(.activate(sport), ["Default": base, "Sport": base]))
        #expect(arrived(.activate(sport), ["Default": base, "Sport": base], active: "sport"))

        #expect(!arrived(.delete(sport), ["Default": base, "Sport": base]))
        #expect(arrived(.delete(sport), ["Default": base]))

        let edit = ProfileCommand.save(name: "Sport", original: sport, values: sport.values)
        #expect(!arrived(edit, ["Default": base, "Sport": base]))
        #expect(arrived(edit, ["Default": base, "Sport": changed]))

        let rename = ProfileCommand.save(name: "Gym", original: sport, values: sport.values)
        #expect(!arrived(rename, ["Default": base, "Sport": base]))
        #expect(arrived(rename, ["Default": base, "Gym": base]))
    }

    @Test("schedule start times show as the looper's wall-clock times, whatever this phone's time zone")
    func startTimesIgnoreThisPhonesTimeZone() throws {
        let starts = Array(stride(from: 0, to: 86400, by: 1800))
        let utc = DateFormatter()
        utc.timeStyle = .short
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let texts = starts.map(ProfileValueFormat.timeText)
        #expect(texts == starts.map { utc.string(from: Date(timeIntervalSince1970: TimeInterval($0))) })
        #expect(Set(texts).count == starts.count)
    }

    @Test("Glucose values in mmol/L show one decimal; other values keep theirs")
    func mmolGlucoseOneDecimal() {
        func local(_ text: String) -> String {
            text.replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
        }
        let range = EditableSegment(seconds: 0, value: 5.551, high: 6.106)
        #expect(ProfileValueFormat.segmentText(range, kind: .correctionRange, limits: nil, glucoseUnits: "mmol/L") == local("5.6 – 6.1"))
        #expect(ProfileValueFormat.text(2.498, kind: .sensitivity, limits: nil, glucoseUnits: "mmol") == local("2.5"))
        #expect(ProfileValueFormat.text(100, kind: .correctionRange, limits: nil, glucoseUnits: "mg/dL") == "100")
        #expect(ProfileValueFormat.text(0.075, kind: .basal, limits: nil, glucoseUnits: "mmol/L") == local("0.075"))
    }

    @Test("Trio profiles carry one target per time: the draft sends high equal to low")
    func trioSingleTarget() throws {
        let values = TherapyProfileValues(
            units: "mg/dL",
            basal: [ProfileScheduleItem(seconds: 0, value: 0.85)],
            carbRatio: [ProfileScheduleItem(seconds: 0, value: 10)],
            sensitivity: [ProfileScheduleItem(seconds: 0, value: 50)],
            target: [ProfileRangeItem(seconds: 0, low: 100, high: 110)]
        )
        #expect(ProfileDraft(values).values.target == [ProfileRangeItem(seconds: 0, low: 100, high: 110)])
        let trio = ProfileDraft(values, singleTarget: true)
        #expect(trio.values.target == [ProfileRangeItem(seconds: 0, low: 100, high: 100)])
        #expect(ProfileValueFormat.segmentText(trio.target[0], kind: .correctionRange, limits: nil, glucoseUnits: "mg/dL", singleTarget: true) == "100")
        #expect(ProfileRemote.trio.hasSingleTarget)
        #expect(!ProfileRemote.loop.hasSingleTarget)

        // The fingerprint LoopFollow computes from the values it sends equals the one of the store entry Trio uploads.
        let sent = trio.values
        let uploaded = try TherapyProfile(name: "Sport", store: Self.store(units: "mg/dL", sens: 50, low: 100, high: 100, basal: [(0, 0.85)]), documentUnits: "mg/dL")
        #expect(sent.fingerprint == uploaded.fingerprint)
    }

    @Test("a save is refused when the profile changed or its active state differs from the review")
    func saveStaleReason() throws {
        let sport = try Self.store(units: "mg/dL", sens: 50, low: 100, high: 110)
        let changed = try Self.store(units: "mg/dL", sens: 55, low: 100, high: 110)
        let reviewed = TherapyProfileSet(Self.document(["Default": sport, "Sport": sport], active: "Default"))
        let original = try #require(reviewed.profile(named: "Sport"))
        func reason(_ store: [String: NSProfile.Store]?, active: String = "Default", reviewedActive: Bool = false) -> String? {
            ProfileCommandFlow.saveStaleReason(
                original: original,
                reviewedActive: reviewedActive,
                current: store.map { TherapyProfileSet(Self.document($0, active: active)) },
                remote: .loop
            )
        }
        #expect(reason(["Default": sport, "Sport": sport]) == nil)
        #expect(reason(["Default": sport, "Sport": sport], active: "Sport", reviewedActive: true) == nil)
        #expect(reason(["Default": sport, "Sport": sport], active: "Sport")?.contains("became active") == true)
        #expect(reason(["Default": sport, "Sport": sport], reviewedActive: true)?.contains("no longer the active profile") == true)
        #expect(reason(["Default": sport, "Sport": changed])?.contains("changed") == true)
        #expect(reason(["Default": sport])?.contains("no longer in the list") == true)
        #expect(reason(nil)?.contains("could not load") == true)
    }

    @Test("a rename of the active profile is checked as active and keeps the values")
    func renameActiveProfile() throws {
        let sport = try Self.store(units: "mg/dL", sens: 50, low: 100, high: 110)
        let profileSet = TherapyProfileSet(Self.document(["Default": sport, "Sport": sport], active: "Sport"))
        let original = try #require(profileSet.profile(named: "Sport"))
        let rename = ProfileCommand.save(name: "Sport 2", original: original, values: original.values)
        #expect(rename.isRename)
        #expect(!ProfileCommand.save(name: "Sport", original: original, values: original.values).isRename)
        #expect(!ProfileCommand.save(name: "Sport 2", original: nil, values: original.values).isRename)
        #expect(ProfileCommandFlow.saveStaleReason(original: original, reviewedActive: profileSet.isActive(original), current: profileSet, remote: .loop) == nil)
    }

    @Test("profile command keys are logged as their command kind, without the profile name")
    func profileKeysLogWithoutName() {
        #expect(RemoteCommandTracker.logKey(ProfileRemote.trio.key(.save, name: "Sport")) == "trio-profile-save")
        #expect(RemoteCommandTracker.logKey(ProfileRemote.loop.key(.activate, name: "A:B")) == "loop-profile-switch")
        #expect(RemoteCommandTracker.logKey("meal-1234567890") == LogRedactor.tail("meal-1234567890"))
    }

    @Test("Trio's measured push size keeps a margin for the nonce and timestamp of the send")
    func trioPushSizeMargin() {
        #expect(ProfilePushSize.reviewLimit(for: .loop) == APNSDelivery.maxPayloadBytes)
        #expect(ProfilePushSize.reviewLimit(for: .trio) == APNSDelivery.maxPayloadBytes - 64)
    }
}
