// LoopFollow
// PushMessage.swift
// Created by Jonas Björkert.

import Foundation

struct PushMessage: Encodable {
    let aps: [String: Int] = ["content-available": 1]
    var user: String
    var commandType: TRCCommandType
    var bolusAmount: Decimal?
    var target: Int?
    var duration: Int?
    var carbs: Int?
    var protein: Int?
    var fat: Int?
    var sharedSecret: String
    var timestamp: TimeInterval
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
        case aps
        case user
        case commandType = "command_type"
        case bolusAmount = "bolus_amount"
        case target
        case duration
        case carbs
        case protein
        case fat
        case sharedSecret = "shared_secret"
        case timestamp
        case overrideName
        case scheduledTime = "scheduled_time"
        case returnNotification = "return_notification"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aps, forKey: .aps)
        try container.encode(user, forKey: .user)
        try container.encode(commandType.rawValue, forKey: .commandType)
        try container.encodeIfPresent(bolusAmount, forKey: .bolusAmount)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(carbs, forKey: .carbs)
        try container.encodeIfPresent(protein, forKey: .protein)
        try container.encodeIfPresent(fat, forKey: .fat)
        try container.encode(sharedSecret, forKey: .sharedSecret)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(overrideName, forKey: .overrideName)
        try container.encodeIfPresent(scheduledTime, forKey: .scheduledTime)
        try container.encodeIfPresent(returnNotification, forKey: .returnNotification)
    }
}
