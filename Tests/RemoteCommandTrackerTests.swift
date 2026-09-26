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
}
