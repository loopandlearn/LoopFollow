// NSProfile.swift
// LoopFollow
// Created by Jonas Björkert on 2024-07-12.
// Copyright © 2024 Jon Fawcett. All rights reserved.

import Foundation

struct NSProfile: Decodable {
    struct Store: Decodable {
        struct BasalEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }
        struct SensEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }
        struct CarbRatioEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }
        struct OverrideEntry: Decodable {
            let name: String?
            let targetRange: [Double]?
            let duration: Int?
            let insulinNeedsScaleFactor: Double?
            let symbol: String?
        }
        struct TargetEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }

        let basal: [BasalEntry]
        let sens: [SensEntry]
        let carbratio: [CarbRatioEntry]
        let overrides: [OverrideEntry]?
        let target_high: [TargetEntry]?
        let target_low: [TargetEntry]?
        let timezone: String
    }

    let store: [String: Store]
    let defaultProfile: String
    let units: String

    let bundleIdentifier: String?
    let isAPNSProduction: Bool?
    let deviceToken: String?
    let teamID: String?

    struct TrioOverrideEntry: Decodable {
        let name: String
        let duration: Double?
        let percentage: Double?
        let target: Double?
    }
    
    let trioOverrides: [TrioOverrideEntry]?

    enum CodingKeys: String, CodingKey {
        case store
        case defaultProfile
        case units
        case bundleIdentifier
        case isAPNSProduction
        case deviceToken
        case trioOverrides = "overrides"
        case teamID
    }
}
