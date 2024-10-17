//
//  Metric.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-17.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

class Metric {
    var value: Double
    var maxFractionDigits: Int
    var minFractionDigits: Int

    init(value: Double, maxFractionDigits: Int, minFractionDigits: Int) {
        self.value = value
        self.maxFractionDigits = maxFractionDigits
        self.minFractionDigits = minFractionDigits
    }

    func formattedValue() -> String {
        return Localizer.formatToLocalizedString(value, maxFractionDigits: maxFractionDigits, minFractionDigits: minFractionDigits)
    }
}
