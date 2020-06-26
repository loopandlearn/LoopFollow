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
    
    
}
