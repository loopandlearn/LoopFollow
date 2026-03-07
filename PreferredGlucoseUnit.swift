//
//  PreferredGlucoseUnit.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-24.
//

import Foundation
import HealthKit

enum PreferredGlucoseUnit {

    /// LoopFollow’s existing source of truth for unit selection.
    /// NOTE: Do not duplicate the string constant elsewhere—keep it here.
    static func hkUnit() -> HKUnit {
        let unitString = Storage.shared.units.value
        switch unitString {
        case "mmol/L":
            return .millimolesPerLiter
        default:
            return .milligramsPerDeciliter
        }
    }

    /// Maps HKUnit -> GlucoseSnapshot.Unit (our cross-platform enum).
    static func snapshotUnit() -> GlucoseSnapshot.Unit {
        switch hkUnit() {
        case .millimolesPerLiter:
            return .mmol
        default:
            return .mgdl
        }
    }
}