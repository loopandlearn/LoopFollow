// LoopFollow
// HKUnit+Extensions.swift

import Foundation
import HealthKit

extension HKUnit {
    public static let milligramsPerDeciliter: HKUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

    public static let millimolesPerLiter: HKUnit = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())

    var preferredFractionDigits: Int {
        switch self {
        case .minute():
            return 0
        case .milligramsPerDeciliter:
            return 0
        case .millimolesPerLiter:
            return 1
        case .internationalUnit():
            return 3
        default:
            return 0
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
