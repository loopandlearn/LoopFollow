//
//  AlarmData.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

struct AlarmData : Encodable, Decodable{
//    let bgReadings: [ShareGlucoseData]
//    let iob: Double?
//    let cob: Double?
//    let predictionData: [ShareGlucoseData]
//    let latestBoluses: [BolusEntry]
//    let batteryLevel: Double?
//    let latestCarbs: [CarbEntry]
//    let overrideData: [OverrideEntry]
//    let tempTargetData: [TempTargetEntry]
//    let pumpVolume: Double?
    let expireDate: Date?
}
