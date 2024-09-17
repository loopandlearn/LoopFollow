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
    var commandType: String
    var bolusAmount: Decimal?
    var target: Int?
    var duration: Int?
    var carbs: Int?
    var protein: Int?
    var fat: Int?
    var sharedSecret: String
    var timestamp: TimeInterval

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
    }
}
