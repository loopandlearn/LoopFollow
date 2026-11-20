// LoopFollow
// RemoteCommandTrackerTests.swift

import Foundation
@testable import LoopFollow
import Testing

@MainActor
struct RemoteCommandTrackerTests {
    @Test("begin, resolve and consume walk one key through its states")
    func beginResolveConsume() {
        let tracker = RemoteCommandTracker(timeout: 60)
        tracker.begin(key: "K")
        #expect(tracker.isBusy(key: "K"))

        tracker.resolve(key: "K", success: true, message: "Done")
        #expect(tracker.states["K"] == .done(success: true, message: "Done"))
        #expect(!tracker.isBusy(key: "K"))

        tracker.consume(key: "K")
        #expect(tracker.states["K"] == nil)
    }

    @Test("resolve without a pending command is ignored")
    func resolveWhenIdle() {
        let tracker = RemoteCommandTracker(timeout: 60)
        tracker.resolve(key: "K", success: true, message: "Done")
        #expect(tracker.states["K"] == nil)
    }

    @Test("a pending command times out")
    func timeout() async throws {
        let tracker = RemoteCommandTracker(timeout: 0.05)
        tracker.begin(key: "K")
        try await Task.sleep(for: .milliseconds(400))
        #expect(tracker.states["K"] == .done(success: false, message: RemoteCommandTracker.timeoutMessage))
    }

    @Test("acks for unknown keys are ignored")
    func unknownKey() {
        let tracker = RemoteCommandTracker(timeout: 60)
        #expect(tracker.handleNotification(userInfo: ["command_type": "carbs_delete", "command_status": "success", "sync_identifier": "nope"]) == false)
        #expect(tracker.handleNotification(userInfo: ["command_type": "delete_meal", "command_status": "success", "command_id": "nope"]) == false)
        #expect(tracker.states.isEmpty)
    }

    @Test("TRC ack resolves the meal registered under its command id, once")
    func trioAdapter() {
        let tracker = RemoteCommandTracker(timeout: 60)
        tracker.trioAcks.register(commandID: "CMD", key: "MEAL")
        tracker.begin(key: "MEAL")
        let ack: [AnyHashable: Any] = [
            "command_status": "failed",
            "command_type": "delete_meal",
            "command_id": "CMD",
            "meal_id": "MEAL",
            "result": "not_found",
            "aps": ["alert": ["title": "Command Failed", "body": "Meal not found"]],
        ]
        #expect(tracker.handleNotification(userInfo: ack) == true)
        #expect(tracker.states["MEAL"] == .done(success: false, message: "Meal not found"))

        tracker.begin(key: "MEAL")
        #expect(tracker.handleNotification(userInfo: ack) == false)
        #expect(tracker.isBusy(key: "MEAL"))
    }

    @Test("TRC ack without an alert body falls back to the result message")
    func trioDefaultMessage() {
        let adapter = TRCMealAckAdapter()
        adapter.register(commandID: "CMD", key: "MEAL")
        let resolution = adapter.resolution(for: ["command_status": "success", "command_id": "CMD", "result": "updated"])
        #expect(resolution == RemoteCommandTracker.Resolution(key: "MEAL", success: true, message: "Meal updated."))
    }

    @Test("Loop ack resolves by sync identifier")
    func loopAdapter() {
        let tracker = RemoteCommandTracker(timeout: 60)
        tracker.begin(key: "SYNC-1")
        #expect(tracker.handleNotification(userInfo: ["command_type": "carbs_edit", "command_status": "success", "sync_identifier": "SYNC-1"]) == true)
        #expect(tracker.states["SYNC-1"] == .done(success: true, message: "Carb entry updated."))
        #expect(LoopCarbAckAdapter.resolution(for: ["command_type": "meal", "command_status": "success", "sync_identifier": "SYNC-1"]) == nil)
        #expect(LoopCarbAckAdapter.resolution(for: ["command_type": "carbs_delete", "command_status": "failed"]) == nil)
    }

    @Test("Loop profile switch acks resolve the profile named in the message")
    func loopProfileAdapter() {
        let tracker = RemoteCommandTracker(timeout: 60)
        let sickDay = ProfileRemote.loop.key(.activate, name: "Sick Day")
        tracker.begin(key: sickDay)
        let lateSport: [AnyHashable: Any] = [
            "command_type": "profile_switch",
            "command_status": "success",
            "aps": ["alert": ["title": "Command Successful", "body": "Profile 'Sport' activated"]],
        ]
        #expect(tracker.handleNotification(userInfo: lateSport) == false)
        #expect(tracker.isBusy(key: sickDay))
        let failed: [AnyHashable: Any] = [
            "command_type": "profile_switch",
            "command_status": "failed",
            "aps": ["alert": ["title": "Command Failed", "body": "Command failed: Profile 'Sick Day' not activated: Communication Failure"]],
        ]
        #expect(tracker.handleNotification(userInfo: failed) == true)
        #expect(tracker.states[sickDay] == .done(success: false, message: "Command failed: Profile 'Sick Day' not activated: Communication Failure"))
        #expect(LoopProfileAckAdapter.resolution(for: ["command_type": "profile_switch", "command_status": "failed"]) == nil)
        #expect(LoopProfileAckAdapter.resolution(for: ["command_type": "carbs_edit", "command_status": "success"]) == nil)
    }

    @Test("a Loop profile reply without the English frame resolves only the sole pending command of its type")
    func loopProfileReplyWithoutFrame() {
        let localized: [AnyHashable: Any] = [
            "command_type": "profile_switch",
            "command_status": "success",
            "result": "activated",
            "aps": ["alert": ["body": "Profil 'Sport' aktiverad"]],
        ]
        let tracker = RemoteCommandTracker(timeout: 60)
        let sport = ProfileRemote.loop.key(.activate, name: "Sport")
        let save = ProfileRemote.loop.key(.save, name: "Work")
        tracker.begin(key: sport)
        tracker.begin(key: save)
        #expect(tracker.handleNotification(userInfo: localized) == true)
        #expect(tracker.states[sport] == .done(success: true, message: "Profil 'Sport' aktiverad"))
        #expect(tracker.isBusy(key: save))

        let two = RemoteCommandTracker(timeout: 60)
        two.begin(key: ProfileRemote.loop.key(.activate, name: "Sport"))
        two.begin(key: ProfileRemote.loop.key(.activate, name: "Work"))
        #expect(two.handleNotification(userInfo: localized) == false)
    }

    @Test("Loop profile save and delete acks resolve by command type and name, renames by the new name")
    func loopProfileSaveDelete() {
        let tracker = RemoteCommandTracker(timeout: 60)
        let rename = ProfileRemote.loop.key(.save, name: "It's School")
        let delete = ProfileRemote.loop.key(.delete, name: "Old")
        #expect(rename == "loop-profile-save:It's School")
        #expect(delete == "loop-profile-delete:Old")
        tracker.begin(key: rename)
        tracker.begin(key: delete)
        let wrongType: [AnyHashable: Any] = [
            "command_type": "profile_delete",
            "command_status": "success",
            "aps": ["alert": ["body": "Profile 'It's School' saved"]],
        ]
        #expect(tracker.handleNotification(userInfo: wrongType) == false)
        let saved: [AnyHashable: Any] = [
            "command_type": "profile_save",
            "command_status": "success",
            "aps": ["alert": ["title": "Command Successful", "body": "Profile 'It's School' saved"]],
        ]
        #expect(tracker.handleNotification(userInfo: saved) == true)
        #expect(tracker.states[rename] == .done(success: true, message: "Profile 'It's School' saved"))
        let notDeleted: [AnyHashable: Any] = [
            "command_type": "profile_delete",
            "command_status": "failed",
            "aps": ["alert": ["body": "Command failed: Profile 'Old' not deleted: Profile is active"]],
        ]
        #expect(tracker.handleNotification(userInfo: notDeleted) == true)
        #expect(tracker.states[delete] == .done(success: false, message: "Command failed: Profile 'Old' not deleted: Profile is active"))
        #expect(LoopProfileAckAdapter.profileName(in: "Profile 'A' not saved: conflict", kind: .save) == "A")
        #expect(LoopProfileAckAdapter.profileName(in: "Profile 'A' saved", kind: .delete) == nil)
    }

    @Test("Loop profile names with apostrophes and quoted reasons are matched exactly")
    func loopProfileNames() {
        #expect(LoopProfileAckAdapter.profileName(in: "Profile 'It's School' saved", kind: .save) == "It's School")
        #expect(LoopProfileAckAdapter.profileName(in: "Command failed: Profile 'A' not saved: Profile 'B' saved already", kind: .save) == "A")
        #expect(LoopProfileAckAdapter.profileName(in: "Command failed: Profile 'Mom's' not activated: Profile 'X' activated", kind: .activate) == "Mom's")
        #expect(LoopProfileAckAdapter.profileName(in: "Profile 'A' saved and more", kind: .save) == nil)
        // A name that itself contains the failure phrase is found through the pending commands.
        let tricky = "x' not saved: y"
        let message = "Command failed: Profile '\(tricky)' not saved: conflict"
        #expect(LoopProfileAckAdapter.profileName(in: message, kind: .save) == "x")
        #expect(LoopProfileAckAdapter.profileName(in: message, kind: .save, candidates: ["x", tricky]) == tricky)

        let tracker = RemoteCommandTracker(timeout: 60)
        let key = ProfileRemote.loop.key(.save, name: tricky)
        tracker.begin(key: key)
        let reply: [AnyHashable: Any] = [
            "command_type": "profile_save",
            "command_status": "failed",
            "aps": ["alert": ["body": message]],
        ]
        #expect(tracker.handleNotification(userInfo: reply) == true)
        #expect(tracker.states[key] == .done(success: false, message: message))
    }

    @Test("a pending profile command whose change shows in the uploaded profiles finishes as applied")
    func profileCommandSeen() throws {
        let tracker = RemoteCommandTracker(timeout: 60)
        let profile = try TherapyProfile(name: "Sport", store: TherapyProfileTests.store(units: "mg/dL", sens: 45, low: 100, high: 110))
        let key = tracker.beginProfileCommand(.activate(profile), to: .trio)

        tracker.resolveProfileCommandSeen(.delete(profile))
        #expect(tracker.isBusy(key: key))

        tracker.resolveProfileCommandSeen(.activate(profile))
        #expect(tracker.states[key] == .done(success: true, message: ProfileRemote.trio.seenMessage(.activate(profile))))

        tracker.resolve(key: key, success: false, message: "late reply")
        #expect(tracker.states[key] == .done(success: true, message: ProfileRemote.trio.seenMessage(.activate(profile))))
    }

    @Test("a profile command that times out finishes like a reply and leaves the review")
    func profileTimeout() async throws {
        let tracker = RemoteCommandTracker(timeout: 60)
        let key = ProfileRemote.loop.key(.save, name: "Weekday")
        var completed: [String] = []
        let observer = NotificationCenter.default.addObserver(forName: .remoteMealCommandDidComplete, object: nil, queue: nil) { note in
            if let key = note.userInfo?["key"] as? String { completed.append(key) }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        tracker.begin(key: key, timeout: 0.05, timeoutMessage: ProfileRemote.loop.timeoutMessage)
        for _ in 0 ..< 250 where tracker.isBusy(key: key) || !completed.contains(key) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(tracker.states[key] == .done(success: false, message: ProfileRemote.loop.timeoutMessage))
        #expect(completed.contains(key))
        #expect(ProfileRemote.isProfileCommandKey(key))

        #expect(ProfileCommandFlow.leavesAfterResult(.init(success: false, message: ProfileRemote.loop.timeoutMessage), remote: .loop))
        #expect(ProfileCommandFlow.leavesAfterResult(.init(success: true, message: "Profile 'Weekday' saved"), remote: .loop))
        #expect(!ProfileCommandFlow.leavesAfterResult(.init(success: false, message: "Command failed: Profile 'Weekday' not saved: The basal rate 3.5 U/hr is above the maximum basal rate"), remote: .loop))
        #expect(!ProfileCommandFlow.leavesAfterResult(.init(success: false, message: ProfileRemote.trio.timeoutMessage), remote: .loop))
        #expect(ProfileCommandFlow.leavesAfterResult(.init(success: false, message: "Profile 'Weekday' not saved", outdated: true), remote: .trio))
    }

    @Test("Loop replies are classified by their result code before the alert text")
    func loopResultCodes() {
        let tracker = RemoteCommandTracker(timeout: 60)
        func reply(_ type: String, status: String, result: String?, body: String) -> [AnyHashable: Any] {
            var info: [AnyHashable: Any] = ["command_type": type, "command_status": status, "aps": ["alert": ["body": body]]]
            if let result { info["result"] = result }
            return info
        }
        // Localized text: only the code tells it is a conflict.
        let conflict = ProfileRemote.loop.key(.save, name: "Weekday")
        tracker.begin(key: conflict)
        #expect(tracker.handleNotification(userInfo: reply("profile_save", status: "failed", result: "conflict", body: "Profile 'Weekday' not saved: Profilen har ändrats")))
        #expect(tracker.states[conflict] == .done(success: false, message: "Profile 'Weekday' not saved: Profilen har ändrats", outdated: true))

        let gone = ProfileRemote.loop.key(.delete, name: "Old")
        tracker.begin(key: gone)
        #expect(tracker.handleNotification(userInfo: reply("profile_delete", status: "failed", result: "not_found", body: "Profile 'Old' not deleted: x")))
        #expect(tracker.states[gone] == .done(success: false, message: "Profile 'Old' not deleted: x", outdated: true))

        // A rejection whose text happens to match the English fallback stays a plain refusal.
        let rejected = ProfileRemote.loop.key(.save, name: "School")
        tracker.begin(key: rejected)
        let rejectedBody = "Profile 'School' not saved: No profile named School was expected"
        #expect(tracker.handleNotification(userInfo: reply("profile_save", status: "failed", result: "rejected", body: rejectedBody)))
        #expect(tracker.states[rejected] == .done(success: false, message: rejectedBody))

        let activated = ProfileRemote.loop.key(.activate, name: "Sport")
        tracker.begin(key: activated)
        #expect(tracker.handleNotification(userInfo: reply("profile_switch", status: "success", result: "activated", body: "Profile 'Sport' activated")))
        #expect(tracker.states[activated] == .done(success: true, message: "Profile 'Sport' activated"))

        #expect(LoopProfileAckAdapter.outcome(status: "success", result: "saved", body: "") == (true, false))
        #expect(LoopProfileAckAdapter.outcome(status: "failed", result: nil, body: "The profile changed on the phone after it was uploaded.") == (false, true))
        #expect(LoopProfileAckAdapter.outcome(status: "failed", result: nil, body: "Profilen har ändrats") == (false, false))
    }

    @Test("refusals because the profile changed or is gone are marked outdated, other refusals are not")
    func outdatedRefusals() {
        let tracker = RemoteCommandTracker(timeout: 60)
        let conflict = ProfileRemote.loop.key(.save, name: "Weekday")
        let gone = ProfileRemote.loop.key(.activate, name: "Old")
        let invalid = ProfileRemote.loop.key(.save, name: "School")
        [conflict, gone, invalid].forEach { tracker.begin(key: $0) }
        func reply(_ type: String, _ body: String) -> [AnyHashable: Any] {
            ["command_type": type, "command_status": "failed", "aps": ["alert": ["body": body]]]
        }
        let conflictBody = "Command failed: Profile 'Weekday' not saved: The profile changed on the phone after it was uploaded. Review it again and resend."
        #expect(tracker.handleNotification(userInfo: reply("profile_save", conflictBody)))
        #expect(tracker.states[conflict] == .done(success: false, message: conflictBody, outdated: true))
        #expect(tracker.handleNotification(userInfo: reply("profile_switch", "Profile 'Old' not activated: No profile named Old")))
        #expect(tracker.states[gone] == .done(success: false, message: "Profile 'Old' not activated: No profile named Old", outdated: true))
        #expect(tracker.handleNotification(userInfo: reply("profile_save", "Profile 'School' not saved: The correction range is below the glucose safety limit")))
        #expect(tracker.states[invalid] == .done(success: false, message: "Profile 'School' not saved: The correction range is below the glucose safety limit"))

        let trioKey = ProfileRemote.trio.key(.save, name: "Weekend")
        tracker.begin(key: trioKey)
        tracker.trioAcks.register(commandID: "T1", key: trioKey)
        #expect(tracker.handleNotification(userInfo: ["command_status": "failed", "command_id": "T1", "result": "conflict"]))
        if case let .done(_, _, outdated) = tracker.states[trioKey] { #expect(outdated) } else { Issue.record("not resolved") }
        let trioRejected = ProfileRemote.trio.key(.save, name: "Rejected")
        tracker.begin(key: trioRejected)
        tracker.trioAcks.register(commandID: "T2", key: trioRejected)
        #expect(tracker.handleNotification(userInfo: ["command_status": "failed", "command_id": "T2", "result": "rejected"]))
        if case let .done(_, _, outdated) = tracker.states[trioRejected] { #expect(!outdated) } else { Issue.record("not resolved") }
        #expect(ProfileCommandFlow.resultMessage(.init(success: false, message: "x", outdated: true), remote: .trio).contains("loading the profiles"))
    }

    @Test("Trio profile acks match the command id and fall back to a profile message")
    func trioProfileAck() throws {
        let tracker = RemoteCommandTracker(timeout: 60)
        let command = try ProfileCommand.delete(TherapyProfile(name: "Weekend", store: Self.profileStore()))
        let key = ProfileRemote.trio.key(for: command)
        #expect(key == "trio-profile-delete:Weekend")
        tracker.begin(key: key)
        tracker.trioAcks.register(commandID: "CMD-1", key: key, successMessage: ProfileRemote.trio.successMessage(command), failureMessage: ProfileRemote.trio.failureMessage(command))
        #expect(tracker.handleNotification(userInfo: ["command_status": "success", "command_id": "OTHER", "command_type": "delete_profile"]) == false)
        #expect(tracker.handleNotification(userInfo: ["command_status": "success", "command_id": "CMD-1", "command_type": "delete_profile"]) == true)
        #expect(tracker.states[key] == .done(success: true, message: "Profile 'Weekend' deleted"))
        #expect(ProfileRemote.isProfileCommandKey(key))
        #expect(ProfileRemote.isProfileCommandKey("loop-profile-switch:Sport"))
        #expect(!ProfileRemote.isProfileCommandKey("SYNC-1"))
        #expect(tracker.isBusy(keyPrefixes: ProfileRemote.trio.keyPrefixes) == false)
    }

    @Test("profile commands are gated on the names each app lists")
    func gating() {
        #expect(ProfileRemote.loop.supports(.save, in: ["profile-switch", "profile-save"]))
        #expect(!ProfileRemote.loop.supports(.delete, in: ["profile-switch", "profile-save"]))
        #expect(ProfileRemote.trio.supports(.activate, in: ["switch_profile"]))
        #expect(!ProfileRemote.trio.supportsAny(in: ["edit_meal", "delete_meal", "profile-save"]))
        #expect(ProfileRemote.loop.supportsAny(in: ["profile-delete"]))
    }

    private static func profileStore() throws -> NSProfile.Store {
        let json = """
        {"timezone": "UTC", "units": "mg/dL",
         "basal": [{"time": "00:00", "value": 1, "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": 100, "timeAsSeconds": 0}],
         "target_high": [{"time": "00:00", "value": 110, "timeAsSeconds": 0}]}
        """
        return try JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8))
    }
}
