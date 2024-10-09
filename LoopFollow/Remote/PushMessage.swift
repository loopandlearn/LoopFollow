//
//  PushMessage.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-27.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aps, forKey: .aps)
        try container.encode(user, forKey: .user)
        try container.encode(commandType.rawValue, forKey: .commandType)
        try container.encode(bolusAmount, forKey: .bolusAmount)
        try container.encode(target, forKey: .target)
        try container.encode(duration, forKey: .duration)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(protein, forKey: .protein)
        try container.encode(fat, forKey: .fat)
        try container.encode(sharedSecret, forKey: .sharedSecret)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(overrideName, forKey: .overrideName)
    }
}
