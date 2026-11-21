// LoopFollow
// ScheduledSwitchTests.swift

import CryptoKit
import Foundation
@testable import LoopFollow
import Testing

@MainActor
struct ScheduledSwitchTests {
    private static let weekend = ScheduledProfileSwitch(id: "5A3D9D6E-1C7F-4A52-9C1D-2B3F9E0F7A11", profile: "Weekend", weekday: 7, time: 25200)
    private static let school = ScheduledProfileSwitch(id: "B0E6C2F4-8D1B-4F0E-A6A7-3C2E5D9B1F02", profile: "Default", weekday: 2, time: 21600)

    private static func paused(_ entry: ScheduledProfileSwitch) -> ScheduledProfileSwitch {
        var entry = entry
        entry.paused = true
        return entry
    }

    // MARK: Fingerprint (shared vectors)

    @Test("the list fingerprint matches the shared vectors")
    func fingerprintVectors() {
        let entries = [Self.weekend, Self.school]
        #expect(ScheduledProfileSwitch.canonicalString(entries)
            == "profile=Default;weekday=2;date=-;time=21600;paused=false|profile=Weekend;weekday=7;date=-;time=25200;paused=false")
        #expect(ScheduledProfileSwitch.fingerprint(entries) == "1f4d16404c846d2f")

        let pausedEntries = entries.map(Self.paused)
        #expect(ScheduledProfileSwitch.canonicalString(pausedEntries)
            == "profile=Default;weekday=2;date=-;time=21600;paused=true|profile=Weekend;weekday=7;date=-;time=25200;paused=true")
        #expect(ScheduledProfileSwitch.fingerprint(pausedEntries) == "bc784950a457ba2c")

        #expect(ScheduledProfileSwitch.fingerprint([]) == "e3b0c44298fc1c14")
    }

    @Test("the fingerprint ignores ids and order")
    func fingerprintIgnoresIdentity() {
        let renumbered = [
            ScheduledProfileSwitch(id: "X", profile: "Default", weekday: 2, time: 21600),
            ScheduledProfileSwitch(id: "Y", profile: "Weekend", weekday: 7, time: 25200),
        ]
        #expect(ScheduledProfileSwitch.fingerprint(renumbered) == ScheduledProfileSwitch.fingerprint([Self.weekend, Self.school]))
    }

    // MARK: Compact JSON

    @Test("compact entries carry paused only when true and decode back to the same entries")
    func compactRoundTrip() throws {
        let entries = [Self.paused(Self.weekend), Self.school]
        let data = try JSONEncoder().encode(entries)
        let objects = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(Set(objects[0].keys) == ["id", "profile", "weekday", "time", "paused"])
        #expect(objects[0]["paused"] as? Bool == true)
        #expect(Set(objects[1].keys) == ["id", "profile", "weekday", "time"])
        #expect(try JSONDecoder().decode([ScheduledProfileSwitch].self, from: data) == entries)

        let serialized = try JSONSerialization.data(withJSONObject: entries.map(\.jsonObject))
        #expect(try JSONDecoder().decode([ScheduledProfileSwitch].self, from: serialized) == entries)
    }

    @Test("one-off entries and fractional times do not decode")
    func unsupportedEntries() {
        let oneOff = #"{"id":"A","profile":"Sick","date":"2026-11-14","time":28800}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ScheduledProfileSwitch.self, from: Data(oneOff.utf8)) }
        let fractional = #"{"id":"A","profile":"Sick","weekday":2,"time":28800.5}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ScheduledProfileSwitch.self, from: Data(fractional.utf8)) }
    }

    // MARK: Documents from Loop and Trio

    private static func document(store: [String], active: String, switches: String?, fingerprint: String? = nil, commands: [String] = []) throws -> NSProfile {
        let entry = """
        {"timezone": "Europe/Stockholm", "units": "mg/dL",
         "basal": [{"time": "00:00", "value": 1, "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": 100, "timeAsSeconds": 0}],
         "target_high": [{"time": "00:00", "value": 110, "timeAsSeconds": 0}]}
        """
        var json = #"{"defaultProfile": "\#(active)", "units": "mg/dL", "store": {"#
        json += store.map { "\"\($0)\": \(entry)" }.joined(separator: ",") + "}"
        if let switches { json += #", "scheduledSwitches": \#(switches)"# }
        if let fingerprint { json += #", "scheduledSwitchesFingerprint": "\#(fingerprint)""# }
        json += #", "remoteCommands": [\#(commands.map { "\"\($0)\"" }.joined(separator: ","))]}"#
        return try JSONDecoder().decode(NSProfile.self, from: Data(json.utf8))
    }

    private static let loopSwitches = """
    [{"id":"5A3D9D6E-1C7F-4A52-9C1D-2B3F9E0F7A11","profile":"Weekend","weekday":7,"time":25200},
     {"id":"B0E6C2F4-8D1B-4F0E-A6A7-3C2E5D9B1F02","profile":"Default","weekday":2,"time":21600}]
    """

    @Test("a Loop document's scheduled switches are read with the uploaded fingerprint and the profile time zone")
    func loopDocument() throws {
        let document = try Self.document(store: ["Default", "Weekend"], active: "Default", switches: Self.loopSwitches, fingerprint: "1f4d16404c846d2f",
                                         commands: ["profile-switch", "profile-scheduled-switches-save"])
        let list = TherapyProfileSet(document).scheduledSwitches
        #expect(list.entries == [Self.weekend, Self.school])
        #expect(list.fingerprint == "1f4d16404c846d2f")
        #expect(list.isComplete)
        #expect(list.timeZone.identifier == "Europe/Stockholm")
        #expect(ProfileRemote.loop.supports(.saveScheduledSwitches, in: document.remoteCommands ?? []))
    }

    @Test("Trio's default is shown as Default while the fingerprint is that of the uploaded names")
    func trioDocument() throws {
        let switches = #"[{"id":"A","profile":"default","weekday":2,"time":21600,"paused":true},{"id":"B","profile":"Weekend","weekday":7,"time":25200}]"#
        let raw = [ScheduledProfileSwitch(id: "A", profile: "default", weekday: 2, time: 21600, paused: true),
                   ScheduledProfileSwitch(id: "B", profile: "Weekend", weekday: 7, time: 25200)]
        let document = try Self.document(store: ["default", "Weekend"], active: "default", switches: switches,
                                         fingerprint: ScheduledProfileSwitch.fingerprint(raw), commands: ["save_scheduled_switches"])
        let list = TherapyProfileSet(document).scheduledSwitches
        #expect(list.entries.map(\.profile) == ["Default", "Weekend"])
        #expect(list.entries[0].paused)
        #expect(list.fingerprint == ScheduledProfileSwitch.fingerprint(raw))
        #expect(list.isComplete)
        #expect(ProfileRemote.trio.supports(.saveScheduledSwitches, in: document.remoteCommands ?? []))
        #expect(!ProfileRemote.loop.supports(.saveScheduledSwitches, in: document.remoteCommands ?? []))
    }

    @Test("a document without scheduled switches has an empty list that can be replaced")
    func missingList() throws {
        let list = try TherapyProfileSet(Self.document(store: ["Default"], active: "Default", switches: nil)).scheduledSwitches
        #expect(list.entries.isEmpty)
        #expect(list.fingerprint == "e3b0c44298fc1c14")
        #expect(list.isComplete)
    }

    @Test("a list with an unreadable entry, a value that is not a list, or another uploaded fingerprint is view-only")
    func incompleteLists() throws {
        let unreadable = #"[{"id":"A","profile":"Weekend","weekday":7,"time":25200},{"id":"B","profile":"Sick","date":"2026-11-14","time":28800}]"#
        let partial = try TherapyProfileSet(Self.document(store: ["Default", "Weekend"], active: "Default", switches: unreadable)).scheduledSwitches
        #expect(partial.entries.count == 1)
        #expect(!partial.isComplete)

        let notAList = try TherapyProfileSet(Self.document(store: ["Default"], active: "Default", switches: #"{"a":1}"#)).scheduledSwitches
        #expect(!notAList.isComplete)

        let mismatch = try TherapyProfileSet(Self.document(store: ["Default", "Weekend"], active: "Default", switches: Self.loopSwitches, fingerprint: "0000000000000000")).scheduledSwitches
        #expect(!mismatch.isComplete)
        #expect(ScheduledSwitchEditing.blocker(mismatch, supported: true, remote: .loop)?.contains("could not be read completely") == true)
        #expect(ScheduledSwitchEditing.blocker(.empty, supported: false, remote: .trio)?.contains("has not said it accepts") == true)
        #expect(ScheduledSwitchEditing.blocker(.empty, supported: true, remote: .loop) == nil)
    }

    // MARK: Validation (the phone's rules)

    private let names = ["Default", "Weekend", "Training day"]

    @Test("a valid week passes")
    func validWeek() {
        #expect(ScheduledSwitches.problems([Self.weekend, Self.school], profileNames: names, appName: "Loop").isEmpty)
        #expect(ScheduledSwitches.problems([], profileNames: names, appName: "Loop").isEmpty)
    }

    @Test("more than 14 starts are refused")
    func tooMany() {
        let entries = (0 ..< 15).map { ScheduledProfileSwitch(profile: "Default", weekday: $0 % 7 + 1, time: ($0 / 7) * 3600) }
        #expect(ScheduledSwitches.problems(Array(entries.prefix(14)), profileNames: names, appName: "Loop").isEmpty)
        #expect(ScheduledSwitches.problems(entries, profileNames: names, appName: "Loop").first?.contains("at most 14") == true)
    }

    @Test("a start of a missing profile is refused, names match case-insensitively")
    func missingProfile() {
        let entry = ScheduledProfileSwitch(profile: "Holiday", weekday: 2, time: 0)
        #expect(ScheduledSwitches.problems([entry], profileNames: names, appName: "Trio") == ["“Holiday” is not a profile in Trio. Choose another profile or delete this start."])
        #expect(ScheduledSwitches.problems([ScheduledProfileSwitch(profile: "default", weekday: 2, time: 0)], profileNames: names, appName: "Trio").isEmpty)
    }

    @Test("two starts in one slot are refused, for two profiles and for the same one")
    func sameSlot() {
        let other = ScheduledProfileSwitch(profile: "Training day", weekday: 7, time: 25200)
        let problems = ScheduledSwitches.problems([Self.weekend, other], profileNames: names, appName: "Loop")
        #expect(problems.count == 1)
        #expect(problems.first?.contains("Only one profile can start at a time") == true)

        let twice = ScheduledProfileSwitch(profile: "Weekend", weekday: 7, time: 25200)
        #expect(ScheduledSwitches.problems([Self.weekend, twice], profileNames: names, appName: "Loop").first?.contains("starts twice") == true)

        // The same time on another weekday is fine.
        let monday = ScheduledProfileSwitch(profile: "Training day", weekday: 2, time: 25200)
        #expect(ScheduledSwitches.problems([Self.weekend, monday], profileNames: names, appName: "Loop").isEmpty)
    }

    @Test("times must be whole minutes of the day and weekdays 1 to 7")
    func timeAndWeekday() {
        for time in [-60, 86400, 25230] {
            let entry = ScheduledProfileSwitch(profile: "Weekend", weekday: 7, time: time)
            #expect(ScheduledSwitches.problems([entry], profileNames: names, appName: "Loop") == ["A start time must be a whole minute of the day."])
        }
        for weekday in [0, 8] {
            let entry = ScheduledProfileSwitch(profile: "Weekend", weekday: weekday, time: 0)
            #expect(ScheduledSwitches.problems([entry], profileNames: names, appName: "Loop") == ["A start has no valid weekday."])
        }
        #expect(ScheduledSwitches.problems([ScheduledProfileSwitch(profile: "Weekend", weekday: 1, time: 86340)], profileNames: names, appName: "Loop").isEmpty)
    }

    // MARK: The week, spans and the next start

    @Test("the week is ordered from Monday and each start lasts until the next unpaused one")
    func weekAndSpans() {
        let sunday = ScheduledProfileSwitch(id: "SUN", profile: "Training day", weekday: 1, time: 21600)
        let entries = [sunday, Self.weekend, Self.school]
        #expect(ScheduledSwitches.sortedForWeek(entries).map(\.id) == [Self.school.id, Self.weekend.id, "SUN"])
        #expect(ScheduledSwitches.following(Self.school, in: entries)?.id == Self.weekend.id)
        #expect(ScheduledSwitches.following(sunday, in: entries)?.id == Self.school.id)

        let pausedWeekend = Self.paused(Self.weekend)
        let withPause = [sunday, pausedWeekend, Self.school]
        #expect(ScheduledSwitches.following(Self.school, in: withPause)?.id == "SUN")
        #expect(ScheduledSwitches.spanText(pausedWeekend, in: withPause) == "Paused")
        #expect(ScheduledSwitches.spanText(Self.school, in: [Self.school]) == "until it starts again next week")
    }

    @Test("the next start is found in the profile time zone and skips paused starts")
    func nextStart() throws {
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        // Friday 2026-11-13 12:00 in New York.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 12)))
        let next = try #require(ScheduledSwitches.next(in: [Self.weekend, Self.school], after: now, timeZone: zone))
        #expect(next.entry.id == Self.weekend.id)
        #expect(next.date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 7)))

        let afterPause = try #require(ScheduledSwitches.next(in: [Self.paused(Self.weekend), Self.school], after: now, timeZone: zone))
        #expect(afterPause.entry.id == Self.school.id)
        #expect(afterPause.date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 6)))
        #expect(ScheduledSwitches.next(in: [Self.paused(Self.weekend)], after: now, timeZone: zone) == nil)
    }

    @Test("a start in the hour skipped by daylight saving runs at the first valid time")
    func springForward() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 12)))
        let entry = ScheduledProfileSwitch(profile: "Weekend", weekday: 1, time: 2 * 3600 + 30 * 60)
        let next = try #require(ScheduledSwitches.nextOccurrence(of: entry, after: saturday, timeZone: zone))
        #expect(next == calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 3)))
    }

    @Test("the footer says what runs next and how many starts are paused")
    func footer() throws {
        let zone = try #require(TimeZone(identifier: "UTC"))
        let friday = Date(timeIntervalSince1970: 1_794_571_200) // 2026-11-13 12:00 UTC
        func list(_ entries: [ScheduledProfileSwitch]) -> ScheduledSwitchList {
            ScheduledSwitchList(entries: entries, fingerprint: ScheduledProfileSwitch.fingerprint(entries), isComplete: true, timeZone: zone)
        }
        let both = ScheduledSwitches.footerText(list([Self.weekend, Self.school]), appName: "Loop", now: friday)
        #expect(both.hasPrefix("Next: Weekend starts Saturday "))
        #expect(!both.contains("paused"))

        let onePaused = ScheduledSwitches.footerText(list([Self.paused(Self.weekend), Self.school]), appName: "Loop", now: friday)
        #expect(onePaused.hasPrefix("Next: Default starts Monday "))
        #expect(onePaused.contains("1 start paused."))
        #expect(onePaused.contains("Default starts again every Monday"))

        let allPaused = ScheduledSwitches.footerText(list([Self.paused(Self.weekend), Self.paused(Self.school)]), appName: "Trio", now: friday)
        #expect(!allPaused.contains("Next:"))
        #expect(allPaused.contains("All starts are paused."))

        #expect(ScheduledSwitches.footerText(list([]), appName: "Trio", now: friday).hasPrefix("No scheduled switches."))
        #expect(ScheduledSwitches.holdText(list([Self.weekend, Self.school]), now: friday)?.hasPrefix("It stays active until Weekend starts Saturday") == true)
        #expect(ScheduledSwitches.holdText(list([]), now: friday) == nil)
    }

    @Test("deleting a profile names the scheduled switches that go with it, counted case-insensitively")
    func deletionText() {
        let weekendSunday = ScheduledProfileSwitch(id: "C4F1A2B3-5D6E-4F70-8A91-B2C3D4E5F6A7", profile: "weekend", weekday: 1, time: 25200)
        let list = ScheduledSwitchList(entries: [Self.weekend, weekendSunday, Self.school], fingerprint: "", isComplete: true, timeZone: .current)
        #expect(ScheduledSwitches.deletionText(list, profileName: "Weekend")
            == "Weekend is used by 2 scheduled switches, which will be removed. At those times the profile active before stays active until the next scheduled start.")
        #expect(ScheduledSwitches.deletionText(list, profileName: "Default")?.hasPrefix("Default is used by 1 scheduled switch, which will be removed.") == true)
        #expect(ScheduledSwitches.deletionText(list, profileName: "Sport") == nil)
    }

    // MARK: Pause, resume and the review diff

    @Test("pausing a start changes only that start's paused flag, and the diff lists it as paused")
    func pauseOneRow() {
        let old = [Self.weekend, Self.school]
        let new = ScheduledSwitches.togglingPause(of: Self.weekend.id, in: old)
        #expect(new[0] == Self.paused(Self.weekend))
        #expect(new[1] == Self.school)
        let changes = ScheduledSwitchDiff.changes(from: old, to: new)
        #expect(changes.map(\.kind) == [.paused])
        #expect(changes.first?.text.hasPrefix("Paused: Weekend starts Saturday") == true)
        #expect(ScheduledProfileSwitch.fingerprint(new) != ScheduledProfileSwitch.fingerprint(old))

        let resumed = ScheduledSwitches.togglingPause(of: Self.weekend.id, in: new)
        #expect(resumed == old)
        #expect(ScheduledSwitchDiff.changes(from: new, to: resumed).map(\.kind) == [.resumed])
        #expect(ScheduledSwitchDiff.newlyStartingProfiles(from: new, to: resumed) == ["Weekend"])
        #expect(ScheduledSwitchDiff.newlyStartingProfiles(from: old, to: new).isEmpty)
    }

    @Test("the diff lists added, removed and changed starts by id, in week order")
    func diff() {
        var moved = Self.weekend
        moved.time = 13 * 3600
        let added = ScheduledProfileSwitch(id: "NEW", profile: "Training day", weekday: 3, time: 21600)
        let changes = ScheduledSwitchDiff.changes(from: [Self.weekend, Self.school], to: [added, moved])
        #expect(changes.map(\.kind) == [.added, .changed, .removed])
        #expect(changes[1].old == Self.weekend)
        #expect(changes[1].new == moved)
        #expect(changes[2].old == Self.school)
        #expect(ScheduledSwitchDiff.changes(from: [Self.weekend], to: [Self.weekend]).isEmpty)
        #expect(ScheduledSwitchDiff.newlyStartingProfiles(from: [Self.weekend, Self.school], to: [added, moved]) == ["Training day", "Weekend"])
    }

    // MARK: Commands

    @Test("the Loop command carries the list as a JSON array and the reviewed fingerprint")
    func loopPayload() throws {
        let entries = [Self.paused(Self.weekend), Self.school]
        let json = LoopAPNSCommands.scheduledSwitchesSaveCommandPayload(entries: entries, baseFingerprint: "1f4d16404c846d2f", otp: "123456",
                                                                        now: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(Set(json.keys) == ["otp", "remote-address", "notes", "entered-by", "sent-at", "expiration", "alert",
                                   "profile-scheduled-switches-save", "profile-scheduled-switches-base-fingerprint"])
        #expect(json["profile-scheduled-switches-base-fingerprint"] as? String == "1f4d16404c846d2f")
        let body = try #require(try JSONSerialization.jsonObject(with: LoopAPNSCommands.apnsBody(json)) as? [String: Any])
        let list = try #require(body["profile-scheduled-switches-save"] as? [[String: Any]])
        #expect(list.count == 2)
        #expect(list[0]["paused"] as? Bool == true)
        #expect(list[1]["paused"] == nil)
        #expect(list[1]["weekday"] as? Int == 2)
        #expect(list[1]["time"] as? Int == 21600)
        let decoded = try JSONDecoder().decode([ScheduledProfileSwitch].self, from: JSONSerialization.data(withJSONObject: list))
        #expect(decoded == entries)

        let empty = LoopAPNSCommands.scheduledSwitchesSaveCommandPayload(entries: [], baseFingerprint: "1f4d16404c846d2f", otp: "123456")
        #expect((empty["profile-scheduled-switches-save"] as? [Any])?.isEmpty == true)
    }

    @Test("the Trio command uses snake_case fields and its own collapse id")
    func trioPayload() throws {
        let payload = CommandPayload(user: "u", commandType: .saveScheduledSwitches, timestamp: 1_700_000_000, commandID: "CMD",
                                     baseFingerprint: "1f4d16404c846d2f", scheduledSwitches: [Self.paused(Self.weekend), Self.school])
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(json["command_type"] as? String == "save_scheduled_switches")
        #expect(json["base_fingerprint"] as? String == "1f4d16404c846d2f")
        #expect(json["command_id"] as? String == "CMD")
        #expect(json["profile_name"] == nil)
        #expect(json["profile"] == nil)
        let list = try #require(json["scheduled_switches"] as? [[String: Any]])
        #expect(list.map { $0["profile"] as? String } == ["Weekend", "Default"])
        #expect(list[0]["paused"] as? Bool == true)
        #expect(payload.apnsCollapseID == "CMD")
        #expect(TRCCommandType.saveScheduledSwitches.displayName == "Save Scheduled Switches")
    }

    private static let returnInfo = ReturnNotificationInfo(
        productionEnvironment: true,
        deviceToken: String(repeating: "a", count: 64),
        bundleId: "com.TEAMID1234.LoopFollow",
        teamId: "TEAMID1234",
        keyId: "KEYID12345",
        apnsKey: "-----BEGIN PRIVATE KEY-----\n" + String(repeating: "A", count: 200) + "\n-----END PRIVATE KEY-----"
    )

    private static func loopSize(_ entries: [ScheduledProfileSwitch]) throws -> Int {
        var payload = LoopAPNSCommands.scheduledSwitchesSaveCommandPayload(entries: entries, baseFingerprint: "1f4d16404c846d2f", otp: "123456")
        payload["encrypted_return_notification"] = try #require(OTPSecureMessenger(otpCode: "123456")).encrypt(returnInfo)
        return try LoopAPNSCommands.apnsBody(payload).count
    }

    private static func trioSize(_ entries: [ScheduledProfileSwitch]) throws -> Int {
        let payload = CommandPayload(user: "Caregiver", commandType: .saveScheduledSwitches, timestamp: Date().timeIntervalSince1970, commandID: UUID().uuidString,
                                     baseFingerprint: "1f4d16404c846d2f", scheduledSwitches: entries, returnNotification: returnInfo)
        let messenger = try #require(SecureMessenger(sharedSecret: "secret"))
        return try JSONEncoder().encode(EncryptedPushMessage(encryptedData: messenger.encrypt(payload), commandType: .saveScheduledSwitches)).count
    }

    @Test("14 paused starts with ordinary names fit one push for Loop and Trio; extreme names are refused by size")
    func payloadSize() throws {
        func week(_ name: String) -> [ScheduledProfileSwitch] {
            (0 ..< ScheduledProfileSwitch.maxCount).map { ScheduledProfileSwitch(profile: name, weekday: $0 % 7 + 1, time: ($0 / 7) * 43200 + 1380 * 60, paused: true) }
        }
        let ordinary = week(String(repeating: "W", count: 20))
        #expect(try Self.loopSize(ordinary) <= APNSDelivery.maxPayloadBytes)
        #expect(try Self.trioSize(ordinary) <= ProfilePushSize.reviewLimit(for: .trio))

        let extreme = week(String(repeating: "👨‍👩‍👧‍👦", count: ProfileValidation.maxNameLength))
        #expect(try Self.loopSize(extreme) > APNSDelivery.maxPayloadBytes)
        #expect(try Self.trioSize(extreme) > APNSDelivery.maxPayloadBytes)
        #expect(ScheduledSwitchesPushSize.tooLargeMessage(5000).contains("too large to send remotely"))
    }

    // MARK: Replies

    private static func loopReply(status: String, result: String?, body: String) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = ["command_type": "profile_scheduled_switches_save", "command_status": status, "aps": ["alert": ["body": body]]]
        if let result { userInfo["result"] = result }
        return userInfo
    }

    @Test("Loop replies resolve the pending scheduled switches command by their result code")
    func loopReplies() {
        let key = ProfileRemote.loop.key(for: .saveScheduledSwitches([], baseFingerprint: "x"))
        #expect(key == "loop-profile-scheduled-switches-save:scheduled-switches")
        #expect(ProfileRemote.isProfileCommandKey(key))
        let cases: [(String, String?, String, Bool, Bool)] = [
            ("success", "saved", "Scheduled switches saved", true, false),
            ("failed", "conflict", "Scheduled switches not saved: The scheduled switches changed on the phone.", false, true),
            ("failed", "not_found", "Scheduled switches not saved: No profile named Holiday.", false, true),
            ("failed", "rejected", "Scheduled switches not saved: There can be at most 14 scheduled switches.", false, false),
            ("success", nil, "Scheduled switches saved", true, false),
            ("failed", nil, "Scheduled switches not saved: expired", false, false),
        ]
        for (status, result, body, success, outdated) in cases {
            let tracker = RemoteCommandTracker(timeout: 60)
            tracker.begin(key: key)
            #expect(tracker.handleNotification(userInfo: Self.loopReply(status: status, result: result, body: body)))
            #expect(tracker.states[key] == .done(success: success, message: body, outdated: outdated))
        }
        // A profile save reply does not resolve it.
        let tracker = RemoteCommandTracker(timeout: 60)
        tracker.begin(key: key)
        #expect(tracker.handleNotification(userInfo: ["command_type": "profile_save", "command_status": "success", "aps": ["alert": ["body": "Profile 'A' saved"]]]) == false)
        #expect(tracker.isBusy(key: key))
        #expect(tracker.isBusy(keyPrefixes: ProfileRemote.loop.keyPrefixes))
    }

    @Test("Trio replies resolve by command id, with the Loop texts when the reply has no body")
    func trioReplies() {
        let command = ProfileCommand.saveScheduledSwitches([Self.weekend], baseFingerprint: "x")
        let key = ProfileRemote.trio.key(for: command)
        #expect(key == "trio-profile-scheduled-switches-save:scheduled-switches")
        for (status, result, message, outdated) in [
            ("success", "saved", "Scheduled switches saved", false),
            ("failed", "conflict", "Scheduled switches not saved", true),
            ("failed", "rejected", "Scheduled switches not saved", false),
        ] {
            let tracker = RemoteCommandTracker(timeout: 60)
            tracker.begin(key: key)
            tracker.trioAcks.register(commandID: "CMD", key: key, successMessage: ProfileRemote.trio.successMessage(command), failureMessage: ProfileRemote.trio.failureMessage(command))
            #expect(tracker.handleNotification(userInfo: ["command_status": status, "command_id": "CMD", "command_type": "save_scheduled_switches", "result": result]))
            #expect(tracker.states[key] == .done(success: status == "success", message: message, outdated: outdated))
        }
        #expect(ProfileCommandFlow.resultTitle(kind: .saveScheduledSwitches, success: true, message: "", remote: .trio) == "Scheduled Switches Saved")
        #expect(ProfileCommandFlow.resultTitle(kind: .saveScheduledSwitches, success: false, message: "", remote: .trio) == "Scheduled Switches Not Saved")
    }

    // MARK: Before sending and after the reply

    private static func profileSet(_ entries: [ScheduledProfileSwitch], profiles: [String] = ["Default", "Weekend"]) throws -> TherapyProfileSet {
        let store = try TherapyProfileTests.store(units: "mg/dL", sens: 50, low: 100, high: 110, basal: [(0, 1.0)])
        return TherapyProfileSet(
            profiles: profiles.map { TherapyProfile(name: $0, store: store) },
            activeName: "Default",
            uploadedAt: nil,
            scheduledSwitches: ScheduledSwitchList(entries: entries, fingerprint: ScheduledProfileSwitch.fingerprint(entries), isComplete: true, timeZone: .current)
        )
    }

    @Test("a newly starting profile that gives more insulin than Default is found also when its units differ")
    func moreInsulinAcrossUnits() throws {
        let base = try TherapyProfile(name: "Default", store: TherapyProfileTests.store(units: "mg/dL", sens: 50, low: 100, high: 110, basal: [(0, 1.0)]))
        let stronger = try TherapyProfile(name: "Weekend", store: TherapyProfileTests.store(units: "mmol/L", sens: 2.0, low: 5.6, high: 6.2, basal: [(0, 1.0)]))
        let same = try TherapyProfile(name: "Weekend", store: TherapyProfileTests.store(units: "mmol/L", sens: 2.8, low: 5.6, high: 6.2, basal: [(0, 1.0)]))

        let found = ScheduledSwitchDiff.moreInsulinProfiles(from: [], to: [Self.weekend], profiles: [base, stronger])
        #expect(found.map(\.profile.name) == ["Weekend"])
        #expect(found.first?.increases.map(\.kind).contains(.sensitivity) == true)
        #expect(ScheduledSwitchDiff.moreInsulinProfiles(from: [], to: [Self.weekend], profiles: [base, same]).isEmpty)
        #expect(ScheduledSwitchDiff.moreInsulinProfiles(from: [Self.weekend], to: [Self.weekend], profiles: [base, stronger]).isEmpty)
    }

    @Test("a list is not sent when the phone's list or its profiles changed since the review")
    func staleBeforeSending() throws {
        let reviewed = [Self.weekend, Self.school]
        let base = ScheduledProfileSwitch.fingerprint(reviewed)
        let new = ScheduledSwitches.togglingPause(of: Self.weekend.id, in: reviewed)
        #expect(try ScheduledSwitchesReviewView.staleReason(baseFingerprint: base, entries: new, current: Self.profileSet(reviewed), remote: .loop) == nil)
        let changed = try Self.profileSet([Self.weekend])
        #expect(ScheduledSwitchesReviewView.staleReason(baseFingerprint: base, entries: new, current: changed, remote: .loop)?.contains("changed in Loop while you were editing") == true)
        let deleted = try Self.profileSet(reviewed, profiles: ["Default"])
        #expect(ScheduledSwitchesReviewView.staleReason(baseFingerprint: base, entries: new, current: deleted, remote: .trio)?.contains("“Weekend” is no longer") == true)
        #expect(ScheduledSwitchesReviewView.staleReason(baseFingerprint: base, entries: new, current: nil, remote: .trio)?.contains("could not load") == true)
    }

    @Test("the follow-up fetches stop once the uploaded list is no longer the one replaced")
    func refreshStops() throws {
        let old = [Self.weekend, Self.school]
        let command = ProfileCommand.saveScheduledSwitches(ScheduledSwitches.togglingPause(of: Self.weekend.id, in: old), baseFingerprint: ScheduledProfileSwitch.fingerprint(old))
        let before = try Self.profileSet(old)
        #expect(!RemoteCommandRefresh.profileArrived(command, before: before, now: before))
        let after = try Self.profileSet(ScheduledSwitches.togglingPause(of: Self.weekend.id, in: old))
        #expect(RemoteCommandRefresh.profileArrived(command, before: before, now: after))
        #expect(!RemoteCommandRefresh.profileArrived(command, before: before, now: nil))
    }

    @Test("the scheduled switches command is gated on the name each app lists")
    func gating() {
        #expect(ProfileRemote.loop.supports(.saveScheduledSwitches, in: ["profile-scheduled-switches-save"]))
        #expect(!ProfileRemote.loop.supports(.saveScheduledSwitches, in: ["profile-switch", "profile-save", "profile-delete"]))
        #expect(ProfileRemote.trio.supports(.saveScheduledSwitches, in: ["save_scheduled_switches"]))
        #expect(!ProfileRemote.trio.supports(.saveScheduledSwitches, in: ["switch_profile", "save_profile", "delete_profile", "profile-scheduled-switches-save"]))
    }
}
