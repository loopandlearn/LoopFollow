//
//  NSProfile.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-12.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

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

        let basal: [BasalEntry]
        let sens: [SensEntry]
        let carbratio: [CarbRatioEntry]
        let overrides: [OverrideEntry]?
        let timezone: String
    }

    let store: [String: Store]
    let defaultProfile: String
    let units: String
}
