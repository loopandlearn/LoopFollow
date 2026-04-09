// LoopFollow
// PreferredGlucoseUnit.swift

import Foundation
import HealthKit

enum PreferredGlucoseUnit {
    /// LoopFollow’s existing source of truth for unit selection.
    static func hkUnit() -> HKUnit {
        Localizer.getPreferredUnit()
    }

    /// Maps HKUnit -> GlucoseSnapshot.Unit (our cross-platform enum).
    static func snapshotUnit() -> GlucoseSnapshot.Unit {
        switch hkUnit() {
        case .millimolesPerLiter:
            .mmol
        default:
            .mgdl
        }
    }
}
