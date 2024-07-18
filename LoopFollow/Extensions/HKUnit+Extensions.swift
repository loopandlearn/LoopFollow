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
}
