// LoopFollow
// PushMessage.swift

import Foundation

struct EncryptedPushMessage: Encodable {
    let aps: [String: Int] = ["content-available": 1]

    let encryptedData: String

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
    var returnNotification: ReturnNotificationInfo?

    struct ReturnNotificationInfo: Encodable {
        let productionEnvironment: Bool
        let deviceToken: String
        let bundleId: String
        let teamId: String
        let keyId: String
        let apnsKey: String

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
        case returnNotification = "return_notification"
    }
}
