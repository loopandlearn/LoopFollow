//
//  CarbMetric.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-17.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

class CarbMetric: Metric {
    init?(from dictionary: [String: AnyObject], key: String) {
        guard let value = dictionary[key] as? Double else {
            return nil
        }
        super.init(value: value, maxFractionDigits: 0, minFractionDigits: 0)
    }

    init?(from object: AnyObject?, key: String) {
        guard let dictionary = object as? [String: AnyObject], let value = dictionary[key] as? Double else {
            return nil
        }
        super.init(value: value, maxFractionDigits: 0, minFractionDigits: 0)
    }
}
