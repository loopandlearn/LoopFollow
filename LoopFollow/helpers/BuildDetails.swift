//
//  BuildDetails.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-03-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

class BuildDetails {
    static var `default` = BuildDetails()
    
    let dict: [String: Any]
    
    init() {
        guard let url = Bundle.main.url(forResource: "BuildDetails", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            dict = [:]
            return
        }
        dict = parsed
    }
    
    var buildDateString: String? {
        return dict["com-LoopFollow-date"] as? String
    }
}
