//
//  Enums.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/23/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

class DataStructs {
    
    //NS BG Struct
    struct sgvData: Codable {
        var sgv: Int
        var date: TimeInterval
        var direction: String?
    }
    
    // Pie Chart Data
    struct pieData: Codable {
        var name: String
        var value: Double
    }
    
    //NS Basal Profile  Struct
    struct basal2DayProfile: Codable {
        var basalRate: Double
        var startDate: TimeInterval
        var endDate: TimeInterval
    }
    
    //NS Override Data  Struct
    struct overrideGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
    }
    
    
}
