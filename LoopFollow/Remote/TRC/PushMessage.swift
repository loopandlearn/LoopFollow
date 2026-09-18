// LoopFollow
// PushMessage.swift

import Foundation

struct EncryptedPushMessage: Encodable {
    let aps: APSPayload
    let encryptedData: String

    init(encryptedData: String, commandType: TRCCommandType) {
        self.encryptedData = encryptedData
        aps = APSPayload(alert: "Remote Command: \(commandType.displayName)")
    }

    struct APSPayload: Encodable {
        let contentAvailable: Int = 1
        let interruptionLevel: String = "time-sensitive"
        let alert: String

        enum CodingKeys: String, CodingKey {
            case contentAvailable = "content-available"
            case interruptionLevel = "interruption-level"
            case alert
        }
    }

    enum CodingKeys: String, CodingKey {
        case aps
        case encryptedData = "encrypted_data"
    }
}

struct CommandPayload: Encodable {
    var user: String
    var commandType: TRCCommandType
    var timestamp: TimeInterval

    var bolusAmount: Decimal?
    var target: Int?
    var duration: Int?
    var carbs: Int?
    var protein: Int?
    var fat: Int?
    var overrideName: String?
    var scheduledTime: TimeInterval?
    var commandID: String?
    var mealID: String?
    var expectedCarbs: Int?
    var expectedFat: Int?
    var expectedProtein: Int?
    var expectedMealTime: TimeInterval?
    var returnNotification: ReturnNotificationInfo?

    var apnsCollapseID: String? {
        commandType.isMealMutation ? commandID : commandType.rawValue
    }

    struct ReturnNotificationInfo: Encodable {
        let productionEnvironment: Bool
        let deviceToken: String
        let bundleId: String
        let teamId: String
        let keyId: String
        let apnsKey: String

        var isComplete: Bool {
            !deviceToken.isEmpty &&
                !bundleId.isEmpty &&
                !teamId.isEmpty &&
                !keyId.isEmpty &&
                !apnsKey.isEmpty
        }

        enum CodingKeys: String, CodingKey {
            case productionEnvironment = "production_environment"
            case deviceToken = "device_token"
            case bundleId = "bundle_id"
            case teamId = "team_id"
            case keyId = "key_id"
            case apnsKey = "apns_key"
        }
    }

    enum CodingKeys: String, CodingKey {
        case user
        case commandType = "command_type"
        case timestamp
        case bolusAmount = "bolus_amount"
        case target
        case duration
        case carbs
        case protein
        case fat
        case overrideName
        case scheduledTime = "scheduled_time"
        case commandID = "command_id"
        case mealID = "meal_id"
        case expectedCarbs = "expected_carbs"
        case expectedFat = "expected_fat"
        case expectedProtein = "expected_protein"
        case expectedMealTime = "expected_meal_time"
        case returnNotification = "return_notification"
    }
}

extension CommandPayload {
    static func editMeal(
        user: String,
        timestamp: TimeInterval,
        commandID: UUID,
        mealID: UUID,
        expectedCarbs: Int,
        expectedFat: Int,
        expectedProtein: Int,
        expectedMealTime: TimeInterval,
        carbs: Int,
        fat: Int,
        protein: Int,
        scheduledTime: TimeInterval,
        returnNotification: ReturnNotificationInfo
    ) -> CommandPayload {
        CommandPayload(
            user: user,
            commandType: .editMeal,
            timestamp: timestamp,
            carbs: carbs,
            protein: protein,
            fat: fat,
            scheduledTime: scheduledTime,
            commandID: commandID.uuidString,
            mealID: mealID.uuidString,
            expectedCarbs: expectedCarbs,
            expectedFat: expectedFat,
            expectedProtein: expectedProtein,
            expectedMealTime: expectedMealTime,
            returnNotification: returnNotification
        )
    }

    static func deleteMeal(
        user: String,
        timestamp: TimeInterval,
        commandID: UUID,
        mealID: UUID,
        expectedCarbs: Int,
        expectedFat: Int,
        expectedProtein: Int,
        expectedMealTime: TimeInterval,
        returnNotification: ReturnNotificationInfo
    ) -> CommandPayload {
        CommandPayload(
            user: user,
            commandType: .deleteMeal,
            timestamp: timestamp,
            commandID: commandID.uuidString,
            mealID: mealID.uuidString,
            expectedCarbs: expectedCarbs,
            expectedFat: expectedFat,
            expectedProtein: expectedProtein,
            expectedMealTime: expectedMealTime,
            returnNotification: returnNotification
        )
    }
}
