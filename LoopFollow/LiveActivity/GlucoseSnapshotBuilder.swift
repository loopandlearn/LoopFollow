// LoopFollow
// GlucoseSnapshotBuilder.swift

import Foundation

/// Provides the latest glucose-relevant values from LoopFollow's single source of truth.
/// Intentionally provider-agnostic (Nightscout vs Dexcom doesn't matter).
protocol CurrentGlucoseStateProviding {
    // MARK: - Core Glucose

    /// Canonical glucose value in mg/dL.
    var glucoseMgdl: Double? { get }

    /// Canonical delta in mg/dL.
    var deltaMgdl: Double? { get }

    /// Canonical projected glucose in mg/dL.
    var projectedMgdl: Double? { get }

    /// Timestamp of the last reading.
    var updatedAt: Date? { get }

    /// Trend string from LoopFollow (mapped to GlucoseSnapshot.Trend by the builder).
    var trendCode: String? { get }

    // MARK: - Secondary Metrics

    var iob: Double? { get }
    var cob: Double? { get }

    // MARK: - Extended Metrics

    /// Active override name (nil if no active override).
    var override: String? { get }

    /// Recommended bolus in units.
    var recBolus: Double? { get }

    /// CGM/uploader device battery %.
    var battery: Double? { get }

    /// Pump battery %.
    var pumpBattery: Double? { get }

    /// Formatted current basal rate string (empty if not available).
    var basalRate: String { get }

    /// Pump reservoir in units (nil if >50U or unknown).
    var pumpReservoirU: Double? { get }

    /// Autosensitivity ratio, e.g. 0.9 = 90%.
    var autosens: Double? { get }

    /// Total daily dose in units.
    var tdd: Double? { get }

    /// BG target low in mg/dL.
    var targetLowMgdl: Double? { get }

    /// BG target high in mg/dL.
    var targetHighMgdl: Double? { get }

    /// Insulin Sensitivity Factor in mg/dL per unit.
    var isfMgdlPerU: Double? { get }

    /// Carb ratio in g per unit.
    var carbRatio: Double? { get }

    /// Total carbs entered today in grams.
    var carbsToday: Double? { get }

    /// Active profile name.
    var profileName: String? { get }

    /// Sensor insert time as Unix epoch seconds UTC (0 = not set).
    var sageInsertTime: TimeInterval { get }

    /// Cannula insert time as Unix epoch seconds UTC (0 = not set).
    var cageInsertTime: TimeInterval { get }

    /// Insulin/pod insert time as Unix epoch seconds UTC (0 = not set).
    var iageInsertTime: TimeInterval { get }

    /// Min predicted BG in mg/dL.
    var minBgMgdl: Double? { get }

    /// Max predicted BG in mg/dL.
    var maxBgMgdl: Double? { get }

    // MARK: - Loop Status

    /// True when LoopFollow detects the loop has not reported in 15+ minutes.
    var isNotLooping: Bool { get }

    // MARK: - Renewal

    /// True when the Live Activity is within renewalWarning seconds of its deadline.
    var showRenewalOverlay: Bool { get }
}

// MARK: - Builder

/// Pure transformation layer. Reads exclusively from the provider — no direct
/// Storage.shared or Observable.shared access. This makes it testable and reusable
/// across Live Activity, Watch, and CarPlay.
enum GlucoseSnapshotBuilder {
    static func build(from provider: CurrentGlucoseStateProviding) -> GlucoseSnapshot? {
        guard
            let glucoseMgdl = provider.glucoseMgdl,
            glucoseMgdl > 0,
            let updatedAt = provider.updatedAt
        else {
            LogManager.shared.log(
                category: .general,
                message: "GlucoseSnapshotBuilder: missing/invalid core values glucoseMgdl=\(provider.glucoseMgdl?.description ?? "nil") updatedAt=\(provider.updatedAt?.description ?? "nil")",
                isDebug: true,
            )
            return nil
        }

        let preferredUnit = PreferredGlucoseUnit.snapshotUnit()
        let deltaMgdl = provider.deltaMgdl ?? 0.0
        let trend = mapTrend(provider.trendCode)

        if provider.showRenewalOverlay {
            LogManager.shared.log(category: .general, message: "[LA] renewal overlay ON")
        }

        LogManager.shared.log(
            category: .general,
            message: "LA snapshot built: updatedAt=\(updatedAt) interval=\(updatedAt.timeIntervalSince1970)",
            isDebug: true,
        )

        return GlucoseSnapshot(
            glucose: glucoseMgdl,
            delta: deltaMgdl,
            trend: trend,
            updatedAt: updatedAt,
            iob: provider.iob,
            cob: provider.cob,
            projected: provider.projectedMgdl,
            override: provider.override,
            recBolus: provider.recBolus,
            battery: provider.battery,
            pumpBattery: provider.pumpBattery,
            basalRate: provider.basalRate,
            pumpReservoirU: provider.pumpReservoirU,
            autosens: provider.autosens,
            tdd: provider.tdd,
            targetLowMgdl: provider.targetLowMgdl,
            targetHighMgdl: provider.targetHighMgdl,
            isfMgdlPerU: provider.isfMgdlPerU,
            carbRatio: provider.carbRatio,
            carbsToday: provider.carbsToday,
            profileName: provider.profileName,
            sageInsertTime: provider.sageInsertTime,
            cageInsertTime: provider.cageInsertTime,
            iageInsertTime: provider.iageInsertTime,
            minBgMgdl: provider.minBgMgdl,
            maxBgMgdl: provider.maxBgMgdl,
            unit: preferredUnit,
            isNotLooping: provider.isNotLooping,
            showRenewalOverlay: provider.showRenewalOverlay,
        )
    }

    // MARK: - Trend Mapping

    private static func mapTrend(_ code: String?) -> GlucoseSnapshot.Trend {
        guard
            let raw = code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !raw.isEmpty
        else { return .unknown }

        if raw.contains("doubleup") || raw.contains("rapidrise") || raw == "up2" || raw == "upfast" {
            return .upFast
        }
        if raw.contains("fortyfiveup") {
            return .upSlight
        }
        if raw.contains("singleup") || raw == "up" || raw == "up1" || raw == "rising" {
            return .up
        }
        if raw.contains("flat") || raw == "steady" || raw == "none" {
            return .flat
        }
        if raw.contains("doubledown") || raw.contains("rapidfall") || raw == "down2" || raw == "downfast" {
            return .downFast
        }
        if raw.contains("fortyfivedown") {
            return .downSlight
        }
        if raw.contains("singledown") || raw == "down" || raw == "down1" || raw == "falling" {
            return .down
        }

        return .unknown
    }
}
