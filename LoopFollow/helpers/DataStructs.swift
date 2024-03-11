//
//  Enums.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/23/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

class DataStructs {
    
    // Pie Chart Data
    struct pieData: Codable {
        var name: String
        var value: Double
    }
    
    //NS Basal Profile  Struct
    struct basalProfileSegment: Codable {
        var basalRate: Double
        var startDate: TimeInterval
        var endDate: TimeInterval
    }
    
    //NS Timestamp Only Data  Struct
    struct timestampOnlyStruct: Codable {
        var date: TimeInterval
        var sgv: Int
    }
    
    //NS Note Data  Struct
    struct noteStruct: Codable {
        var date: TimeInterval
        var sgv: Int
        var note: String
    }
    
    //NS Override Data  Struct
    struct overrideStruct: Codable {
        var insulNeedsScaleFactor: Double
        var date: TimeInterval
        var endDate: TimeInterval
        var duration: Double
        var correctionRange: [Int]
        var enteredBy: String
        var notes: String
        var reason: String
        var sgv: Float
    }
    
}
