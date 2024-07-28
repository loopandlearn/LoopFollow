//
//  TreatmentResponse.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-24.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

struct TreatmentResponse: Decodable {
    let enteredBy: String
    let eventType: String
    let reason: String
    let targetTop: Double
    let targetBottom: Double
    let duration: Int
    let createdAt: String
    let utcOffset: Int
    let id: String

    enum CodingKeys: String, CodingKey {
        case enteredBy = "enteredBy"
        case eventType = "eventType"
        case reason = "reason"
        case targetTop = "targetTop"
        case targetBottom = "targetBottom"
        case duration = "duration"
        case createdAt = "created_at"
        case utcOffset = "utcOffset"
        case id = "_id"
    }
}
