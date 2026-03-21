// LoopFollow
// GlucoseSnapshot.swift

import Foundation

/// Canonical, source-agnostic glucose state used by
/// Live Activity, future Watch complication, and CarPlay.
///
struct GlucoseSnapshot: Codable, Equatable, Hashable {

    // MARK: - Units

    enum Unit: String, Codable, Hashable {
        case mgdl
        case mmol
    }

    // MARK: - Core Glucose

    /// Glucose value in mg/dL (canonical internal unit).
    let glucose: Double

    /// Delta in mg/dL. May be 0.0 if unchanged.
    let delta: Double

    /// Trend direction (mapped from LoopFollow state).
    let trend: Trend

    /// Timestamp of reading.
    let updatedAt: Date

    // MARK: - Secondary Metrics

    /// Insulin On Board
    let iob: Double?

    /// Carbs On Board
    let cob: Double?

    /// Projected glucose in mg/dL (if available)
    let projected: Double?

    // MARK: - Extended InfoType Metrics

    /// Active override name (nil if no active override)
    let override: String?

    /// Recommended bolus in units (nil if not available)
    let recBolus: Double?

    /// CGM/uploader device battery % (nil if not available)
    let battery: Double?

    /// Pump battery % (nil if not available)
    let pumpBattery: Double?

    /// Formatted current basal rate string (empty if not available)
    let basalRate: String

    /// Pump reservoir in units (nil if >50U or unknown)
    let pumpReservoirU: Double?

    /// Autosensitivity ratio, e.g. 0.9 = 90% (nil if not available)
    let autosens: Double?

    /// Total daily dose in units (nil if not available)
    let tdd: Double?

    /// BG target low in​​​​​​​​​​​​​​​​
