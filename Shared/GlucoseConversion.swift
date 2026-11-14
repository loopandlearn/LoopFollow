// LoopFollow
// GlucoseConversion.swift

import Foundation

enum GlucoseConversion {
    static let mmolToMgDl: Double = 18.01559
    static let mgDlToMmolL: Double = 1.0 / mmolToMgDl

    static func toMmol(_ mgdl: Double) -> Double {
        mgdl * mgDlToMmolL
    }

    /// Converts mg/dL to mmol/L rounded to the one-decimal precision used for display.
    static func toDisplayedMmol(_ mgdl: Double) -> Double {
        (toMmol(mgdl) * 10).rounded() / 10
    }

    /// Rounds a mg/dL value to the precision it is shown at: whole mg/dL, or one-decimal mmol/L.
    /// Lines picked in mmol/L are stored as fractional mg/dL, so both units need rounding.
    static func toDisplayPrecision(_ mgdl: Double, mmol: Bool) -> Double {
        mmol ? toDisplayedMmol(mgdl) : mgdl.rounded()
    }
}

/// Which side of the low/high lines a reading falls on.
enum GlucoseBand {
    case low
    case inRange
    case high

    /// Classifies a mg/dL reading at the precision shown to the user, so the result
    /// always matches the displayed number. A reading on a line is in range.
    static func of(_ mgdl: Double, low: Double, high: Double, mmol: Bool) -> GlucoseBand {
        let value = GlucoseConversion.toDisplayPrecision(mgdl, mmol: mmol)
        let lowLimit = GlucoseConversion.toDisplayPrecision(low, mmol: mmol)
        let highLimit = GlucoseConversion.toDisplayPrecision(high, mmol: mmol)

        if value < lowLimit {
            return .low
        }
        if value > highLimit {
            return .high
        }
        return .inRange
    }
}
