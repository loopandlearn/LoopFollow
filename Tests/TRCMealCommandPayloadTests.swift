// LoopFollow
// TRCMealCommandPayloadTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TRCMealCommandPayloadTests {
    private func encode(_ payload: CommandPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    @Test("edit_meal carries ids, explicit macros and the new time")
    func editMealKeys() throws {
        let payload = CommandPayload(
            user: "u",
            commandType: .editMeal,
            timestamp: 1_700_000_000,
            carbs: 45,
            protein: 15,
            fat: 0,
            scheduledTime: 1_700_000_600,
            commandID: "CMD",
            mealID: "MEAL"
        )
        let json = try encode(payload)
        #expect(json["command_type"] as? String == "edit_meal")
        #expect(json["command_id"] as? String == "CMD")
        #expect(json["meal_id"] as? String == "MEAL")
        #expect(json["scheduled_time"] as? Double == 1_700_000_600)
        #expect(json["carbs"] as? Int == 45)
        #expect(json["protein"] as? Int == 15)
        #expect(json["fat"] as? Int == 0)
    }

    @Test("delete_meal carries no macros")
    func deleteMealKeys() throws {
        let payload = CommandPayload(
            user: "u",
            commandType: .deleteMeal,
            timestamp: 1_700_000_000,
            commandID: "CMD",
            mealID: "MEAL"
        )
        let json = try encode(payload)
        #expect(json["command_type"] as? String == "delete_meal")
        #expect(json["meal_id"] as? String == "MEAL")
        #expect(json["carbs"] == nil)
        #expect(json["fat"] == nil)
        #expect(json["protein"] == nil)
        #expect(json["scheduled_time"] == nil)
        #expect(json["bolus_amount"] == nil)
    }

    @Test("known_through_id is sent when set and omitted when nil")
    func knownThroughID() throws {
        let marker = "6566a3c0a1b2c3d4e5f60718"
        let bolus = try encode(CommandPayload(user: "u", commandType: .bolus, timestamp: 0, bolusAmount: 1, knownThroughID: marker))
        let meal = try encode(CommandPayload(user: "u", commandType: .meal, timestamp: 0, carbs: 10, knownThroughID: marker))
        let unknown = try encode(CommandPayload(user: "u", commandType: .bolus, timestamp: 0, bolusAmount: 1))
        #expect(bolus["known_through_id"] as? String == marker)
        #expect(meal["known_through_id"] as? String == marker)
        #expect(unknown.keys.contains("known_through_id") == false)
    }

    @Test("bolus and meal commands carry a fresh command id and the marker")
    func bolusAndMealCommandIDs() throws {
        let marker = "6566a3c0a1b2c3d4e5f60718"
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func bolus() throws -> [String: Any] {
            try encode(PushNotificationManager.bolusPayload(user: "u", bolusAmount: 1, knownThroughID: marker, returnNotification: nil, now: now))
        }
        func meal() throws -> [String: Any] {
            try encode(PushNotificationManager.mealPayload(
                user: "u", bolusAmount: 1, carbs: 10, protein: nil, fat: nil, scheduledTime: nil,
                knownThroughID: marker, returnNotification: nil, now: now
            ))
        }
        let ids = try [bolus(), bolus(), meal(), meal()].map { try #require($0["command_id"] as? String) }
        #expect(Set(ids).count == 4)
        #expect(ids.allSatisfy { UUID(uuidString: $0) != nil })

        let first = try bolus()
        #expect(first["command_type"] as? String == "bolus")
        #expect(first["known_through_id"] as? String == marker)
        #expect(first["timestamp"] as? Double == 1_700_000_000)
        let second = try meal()
        #expect(second["command_type"] as? String == "meal")
        #expect(second["known_through_id"] as? String == marker)
        #expect(PushNotificationManager.mealPayload(
            user: "u", bolusAmount: nil, carbs: 10, protein: nil, fat: nil, scheduledTime: nil,
            knownThroughID: nil, returnNotification: nil
        ).apnsCollapseID == "meal")
    }

    @Test("collapse id is the command id for meal mutations only")
    func collapseID() {
        let edit = CommandPayload(user: "u", commandType: .editMeal, timestamp: 0, commandID: "CMD", mealID: "M")
        let delete = CommandPayload(user: "u", commandType: .deleteMeal, timestamp: 0, commandID: "CMD2", mealID: "M")
        let meal = CommandPayload(user: "u", commandType: .meal, timestamp: 0, carbs: 10, commandID: "CMD3")
        #expect(edit.apnsCollapseID == "CMD")
        #expect(delete.apnsCollapseID == "CMD2")
        #expect(meal.apnsCollapseID == "meal")
    }
}
