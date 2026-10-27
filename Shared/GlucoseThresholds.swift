// LoopFollow
// GlucoseThresholds.swift

import Foundation

/// Fixed glucose cut-offs (mg/dL) shared by the stats, range modes and Live Activity.
/// Range modes read their low/high from here via `TimeInRangeDisplayMode.fixedThresholds`,
/// so a new mode's cut-offs go here first.
enum GlucoseThresholds {
    static let veryLow = 54.0
    static let veryHigh = 250.0
    /// Time in Range, also used by GRI regardless of the selected range mode.
    static let tirLow = 70.0
    static let tirHigh = 180.0
    /// Time in Tight Range.
    static let titrLow = 70.0
    static let titrHigh = 140.0
    /// Extended Tight Range (TING, Time in Normoglycemia).
    static let tingLow = 63.0
    static let tingHigh = 140.0
}
