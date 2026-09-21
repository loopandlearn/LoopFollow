// LoopFollow
// TRCCommandAckTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TRCCommandAckTests {
    private func ack(status: String = "success", result: String? = "deleted", commandID: String? = "CMD", mealID: String? = "MEAL", body: String? = "Meal deleted") -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            "command_status": status,
            "command_type": "delete_meal",
            "timestamp": 1_700_000_000.0,
        ]
        if let result { info["result"] = result }
        if let commandID { info["command_id"] = commandID }
        if let mealID { info["meal_id"] = mealID }
        if let body { info["aps"] = ["alert": ["title": "Command Successful", "body": body], "sound": "default"] }
        return info
    }

    @Test("parses Trio's return notification")
    func parsesAck() {
        let parsed = TRCCommandAck(userInfo: ack())
        #expect(parsed?.status == "success")
        #expect(parsed?.isSuccess == true)
        #expect(parsed?.commandType == "delete_meal")
        #expect(parsed?.result == "deleted")
        #expect(parsed?.commandID == "CMD")
        #expect(parsed?.mealID == "MEAL")
        #expect(parsed?.message == "Meal deleted")
    }

    @Test("requires command_status, tolerates legacy acks without ids")
    func fallbacks() {
        #expect(TRCCommandAck(userInfo: ["command_type": "meal"]) == nil)
        let legacy = TRCCommandAck(userInfo: ack(result: nil, commandID: nil, mealID: nil, body: nil))
        #expect(legacy != nil)
        #expect(legacy?.commandID == nil)
        #expect(legacy?.message == nil)
    }

    @Test("unknown command ids are ignored")
    func ignoresUnknown() {
        #expect(TRCCommandTracker.shared.handleNotification(userInfo: ack(commandID: "nope")) == false)
    }

    @Test("a matching ack completes the pending command")
    func completesPending() async throws {
        let tracker = TRCCommandTracker.shared
        let command = tracker.register(type: .deleteMeal, mealID: "MEAL-1")
        try await Task.sleep(for: .milliseconds(50))
        #expect(tracker.pendingCommand(forMealID: "MEAL-1")?.id == command.id)

        #expect(tracker.handleNotification(userInfo: ack(commandID: command.id, mealID: "MEAL-1")) == true)
        try await Task.sleep(for: .milliseconds(50))
        #expect(tracker.pendingCommand(forMealID: "MEAL-1") == nil)
        let result = tracker.lastResult(forMealID: "MEAL-1")
        #expect(result?.outcome == .deleted)
        #expect(result?.isSuccess == true)
    }

    @Test("result values map to outcomes")
    func outcomes() async throws {
        let tracker = TRCCommandTracker.shared
        let cases: [(String?, String, TRCCommandTracker.Outcome)] = [
            ("updated", "success", .updated(newMealID: "NEW")),
            ("not_found", "failed", .notFound),
            ("rejected", "failed", .rejected),
            (nil, "failed", .failed),
        ]
        for (index, testCase) in cases.enumerated() {
            let mealID = "MEAL-\(index)"
            let command = tracker.register(type: .editMeal, mealID: mealID)
            try await Task.sleep(for: .milliseconds(50))
            tracker.handleNotification(userInfo: ack(status: testCase.1, result: testCase.0, commandID: command.id, mealID: "NEW"))
            try await Task.sleep(for: .milliseconds(50))
            #expect(tracker.lastResult(forMealID: mealID)?.outcome == testCase.2)
        }
    }
}
