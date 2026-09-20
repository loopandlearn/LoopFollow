// LoopFollow
// RemoteMealMutationPayloadTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct RemoteMealMutationPayloadTests {
    private let commandID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let mealID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    @Test("Edit meal JSON includes required zeros and exact Trio field names")
    func editMealEncoding() throws {
        let payload = CommandPayload.editMeal(
            user: "Configured User",
            timestamp: 1_800_000_000,
            commandID: commandID,
            mealID: mealID,
            expectedCarbs: 0,
            expectedFat: 10,
            expectedProtein: 0,
            expectedMealTime: 1_799_996_400,
            carbs: 0,
            fat: 12,
            protein: 0,
            scheduledTime: 1_800_043_200,
            returnNotification: returnNotification
        )

        let json = try encodedJSONObject(payload)

        #expect(Set(json.keys) == [
            "user",
            "command_type",
            "timestamp",
            "command_id",
            "meal_id",
            "expected_carbs",
            "expected_fat",
            "expected_protein",
            "expected_meal_time",
            "carbs",
            "fat",
            "protein",
            "scheduled_time",
            "return_notification",
        ])
        #expect(json["user"] as? String == "Configured User")
        #expect(json["command_type"] as? String == "edit_meal")
        #expect(json["timestamp"] as? TimeInterval == 1_800_000_000)
        #expect(json["command_id"] as? String == commandID.uuidString)
        #expect(json["meal_id"] as? String == mealID.uuidString)
        #expect(json["expected_carbs"] as? Int == 0)
        #expect(json["expected_fat"] as? Int == 10)
        #expect(json["expected_protein"] as? Int == 0)
        #expect(json["expected_meal_time"] as? TimeInterval == 1_799_996_400)
        #expect(json["carbs"] as? Int == 0)
        #expect(json["fat"] as? Int == 12)
        #expect(json["protein"] as? Int == 0)
        #expect(json["scheduled_time"] as? TimeInterval == 1_800_043_200)

        let notification = try #require(json["return_notification"] as? [String: Any])
        #expect(Set(notification.keys) == [
            "production_environment",
            "device_token",
            "bundle_id",
            "team_id",
            "key_id",
            "apns_key",
        ])
    }

    @Test("Delete meal JSON omits replacement and unrelated command fields")
    func deleteMealEncoding() throws {
        let payload = CommandPayload.deleteMeal(
            user: "Configured User",
            timestamp: 1_800_000_000,
            commandID: commandID,
            mealID: mealID,
            expectedCarbs: 0,
            expectedFat: 10,
            expectedProtein: 0,
            expectedMealTime: 1_799_996_400,
            returnNotification: returnNotification
        )

        let json = try encodedJSONObject(payload)

        #expect(Set(json.keys) == [
            "user",
            "command_type",
            "timestamp",
            "command_id",
            "meal_id",
            "expected_carbs",
            "expected_fat",
            "expected_protein",
            "expected_meal_time",
            "return_notification",
        ])
        #expect(json["command_type"] as? String == "delete_meal")
        #expect(json["expected_carbs"] as? Int == 0)
        #expect(json["expected_fat"] as? Int == 10)
        #expect(json["expected_protein"] as? Int == 0)

        let omittedKeys = [
            "carbs",
            "fat",
            "protein",
            "scheduled_time",
            "bolus_amount",
            "target",
            "duration",
            "overrideName",
            "override_name",
        ]
        #expect(omittedKeys.allSatisfy { json[$0] == nil })
    }

    @Test("Mutation collapse IDs use command IDs while legacy commands remain unchanged")
    func collapseIDs() {
        let edit = CommandPayload.editMeal(
            user: "Configured User",
            timestamp: 1_800_000_000,
            commandID: commandID,
            mealID: mealID,
            expectedCarbs: 30,
            expectedFat: 10,
            expectedProtein: 5,
            expectedMealTime: 1_799_996_400,
            carbs: 25,
            fat: 12,
            protein: 6,
            scheduledTime: 1_799_996_700,
            returnNotification: returnNotification
        )
        let delete = CommandPayload.deleteMeal(
            user: "Configured User",
            timestamp: 1_800_000_000,
            commandID: commandID,
            mealID: mealID,
            expectedCarbs: 30,
            expectedFat: 10,
            expectedProtein: 5,
            expectedMealTime: 1_799_996_400,
            returnNotification: returnNotification
        )

        #expect(edit.apnsCollapseID == commandID.uuidString)
        #expect(delete.apnsCollapseID == commandID.uuidString)

        let legacyTypes: [TRCCommandType] = [
            .bolus,
            .tempTarget,
            .cancelTempTarget,
            .meal,
            .startOverride,
            .cancelOverride,
        ]
        for commandType in legacyTypes {
            let legacy = CommandPayload(user: "Configured User", commandType: commandType, timestamp: 1_800_000_000)
            #expect(legacy.apnsCollapseID == commandType.rawValue)
        }
    }

    @Test("Existing meal-create JSON does not acquire mutation fields")
    func existingMealEncodingIsUnchanged() throws {
        let payload = CommandPayload(
            user: "Configured User",
            commandType: .meal,
            timestamp: 1_800_000_000,
            carbs: 30,
            protein: 5,
            fat: 10,
            scheduledTime: 1_799_996_700,
            returnNotification: returnNotification
        )

        let json = try encodedJSONObject(payload)

        #expect(Set(json.keys) == [
            "user",
            "command_type",
            "timestamp",
            "carbs",
            "protein",
            "fat",
            "scheduled_time",
            "return_notification",
        ])
        #expect(json["command_type"] as? String == "meal")
    }

    @Test("Existing bolus, target, and override JSON shapes remain unchanged")
    func otherLegacyEncodingIsUnchanged() throws {
        let bolus = try encodedJSONObject(CommandPayload(
            user: "Configured User",
            commandType: .bolus,
            timestamp: 1_800_000_000,
            bolusAmount: Decimal(string: "1.25"),
            returnNotification: returnNotification
        ))
        #expect(Set(bolus.keys) == [
            "user", "command_type", "timestamp", "bolus_amount", "return_notification",
        ])

        let target = try encodedJSONObject(CommandPayload(
            user: "Configured User",
            commandType: .tempTarget,
            timestamp: 1_800_000_000,
            target: 100,
            duration: 30,
            returnNotification: returnNotification
        ))
        #expect(Set(target.keys) == [
            "user", "command_type", "timestamp", "target", "duration", "return_notification",
        ])

        let override = try encodedJSONObject(CommandPayload(
            user: "Configured User",
            commandType: .startOverride,
            timestamp: 1_800_000_000,
            overrideName: "Exercise",
            returnNotification: returnNotification
        ))
        #expect(Set(override.keys) == [
            "user", "command_type", "timestamp", "overrideName", "return_notification",
        ])
    }

    @Test("Mutation return-notification configuration must be complete")
    func returnNotificationCompleteness() {
        #expect(returnNotification.isComplete)
        let missingDeviceToken = CommandPayload.ReturnNotificationInfo(
            productionEnvironment: true,
            deviceToken: "",
            bundleId: "com.example.LoopFollow",
            teamId: "ABCDEFGHIJ",
            keyId: "KLMNOPQRST",
            apnsKey: "private-key"
        )
        #expect(!missingDeviceToken.isComplete)
    }

    @Test("Return-notification APNS credentials must be usable, not merely nonempty")
    func returnNotificationCredentialValidation() {
        let validPEM = """
        -----BEGIN PRIVATE KEY-----
        AQIDBA==
        -----END PRIVATE KEY-----
        """
        #expect(APNSCredentialValidator.validationErrors(
            keyID: "KLMNOPQRST",
            teamID: "ABCDEFGHIJ",
            apnsKey: validPEM
        ) == nil)
        #expect(APNSCredentialValidator.validationErrors(
            keyID: "bad",
            teamID: "ABCDEFGHIJ",
            apnsKey: "not-a-private-key"
        ) != nil)
    }

    private var returnNotification: CommandPayload.ReturnNotificationInfo {
        CommandPayload.ReturnNotificationInfo(
            productionEnvironment: true,
            deviceToken: "device-token",
            bundleId: "com.example.LoopFollow",
            teamId: "ABCDEFGHIJ",
            keyId: "KLMNOPQRST",
            apnsKey: "private-key"
        )
    }

    private func encodedJSONObject(_ payload: CommandPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
