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
