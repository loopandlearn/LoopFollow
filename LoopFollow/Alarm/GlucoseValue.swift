//
//  GlucoseValue.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-05.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

// Make use of this more clean glucose struct in more places
struct GlucoseValue: Codable {
    let sgv: Int
    let date: Date
}
