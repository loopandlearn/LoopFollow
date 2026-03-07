//
//  GlucoseUnitConversion.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-24.
//

import Foundation

enum GlucoseUnitConversion {

    // 1 mmol/L glucose ≈ 18.0182 mg/dL (commonly rounded to 18)
    // Using 18.0182 is standard for glucose conversions.
    private static let mgdlPerMmol: Double = 18.0182

    static func convertGlucose(_ value: Double, from: GlucoseSnapshot.Unit, to: GlucoseSnapshot.Unit) -> Double {
        guard from != to else { return value }

        switch (from, to) {
        case (.mgdl, .mmol):
            return value / mgdlPerMmol
        case (.mmol, .mgdl):
            return value * mgdlPerMmol
        default:
            return value
        }
    }
}