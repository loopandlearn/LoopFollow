//
//  HKUnit+Extensions.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-15.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import HealthKit

extension HKUnit {
    public static let milligramsPerDeciliter: HKUnit = {
        return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }()

    public static let millimolesPerLiter: HKUnit = {
        return HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
    }()

    var preferredFractionDigits: Int {
        if self == .milligramsPerDeciliter {
            return 0
        } else {
            return 1
        }
    }

    var localizedShortUnitString: String {
        if self == HKUnit.millimolesPerLiter {
            return NSLocalizedString("mmol/L", comment: "The short unit display string for millimoles of glucose per liter")
        } else if self == .milligramsPerDeciliter {
            return NSLocalizedString("mg/dL", comment: "The short unit display string for milligrams of glucose per decilter")
        } else if self == .internationalUnit() {
            return NSLocalizedString("U", comment: "The short unit display string for international units of insulin")
        } else if self == .gram() {
            return NSLocalizedString("g", comment: "The short unit display string for grams")
        } else {
            return String(describing: self)
        }
    }
}
