// LoopFollow
// NSProfile.swift
// Created by Jonas Björkert on 2024-07-15.

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

        struct TargetEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }

        let basal: [BasalEntry]
        let sens: [SensEntry]
        let carbratio: [CarbRatioEntry]
        let target_high: [TargetEntry]?
        let target_low: [TargetEntry]?
        let timezone: String

        let units: String
    }

    let store: [String: Store]
    let defaultProfile: String
    let units: String

    let bundleIdentifier: String?
    let isAPNSProduction: Bool?
    let deviceToken: String?
    let teamID: String?
    let expirationDate: String?

    struct TrioOverrideEntry: Decodable {
        let name: String
        let duration: Double?
        let percentage: Double?
        let target: Double?
    }

    struct LoopSettings: Decodable {
        struct LoopOverridePreset: Decodable {
            let name: String
            let duration: Int?
            let targetRange: [Double]?
            let insulinNeedsScaleFactor: Double?
            let symbol: String?
        }

        let deviceToken: String?
        let bundleIdentifier: String?
        let minimumBGGuard: Double?
        let maximumBolus: Double?
        let maximumBasalRatePerHour: Double?
        let scheduleOverride: ScheduleOverride?
        let dosingStrategy: String?
        let overridePresets: [LoopOverridePreset]?
        let dosingEnabled: Bool?

        struct ScheduleOverride: Decodable {
            let symbol: String?
            let duration: Int?
            let insulinNeedsScaleFactor: Double?
            let name: String?
        }
    }

    let trioOverrides: [TrioOverrideEntry]?
    let loopSettings: LoopSettings?

    enum CodingKeys: String, CodingKey {
        case store
        case defaultProfile
        case units
        case bundleIdentifier
        case isAPNSProduction
        case deviceToken
        case trioOverrides = "overridePresets"
        case loopSettings
        case teamID
        case expirationDate
    }
}
