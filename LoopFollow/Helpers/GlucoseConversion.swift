// LoopFollow
// GlucoseConversion.swift

import Foundation

enum GlucoseConversion {
    static let mmolToMgDl: Double = 18.01559
    static let mgDlToMmolL: Double = 1.0 / mmolToMgDl

    static func toMmol(_ mgdl: Double) -> Double {
        mgdl * mgDlToMmolL
    }
}
