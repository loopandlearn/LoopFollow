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
}

/// Which side of the low/high lines a reading falls on.
enum GlucoseBand {
    case low
    case inRange
    case high

    /// Classifies a mg/dL reading at the precision shown to the user, so the result
    /// always matches the displayed number. A reading on a line is low or high.
    static func of(_ mgdl: Double, low: Double, high: Double, mmol: Bool) -> GlucoseBand {
        let display: (Double) -> Double = mmol ? GlucoseConversion.toDisplayedMmol : { $0 }
        let value = display(mgdl)
        if value <= display(low) { return .low }
        if value >= display(high) { return .high }
        return .inRange
    }
}
