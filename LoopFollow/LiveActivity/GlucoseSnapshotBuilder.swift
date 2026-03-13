// LoopFollow
// GlucoseSnapshotBuilder.swift

import Foundation

/// Provides the *latest* glucose-relevant values from LoopFollow’s single source of truth.
/// This is intentionally provider-agnostic (Nightscout vs Dexcom doesn’t matter).
protocol CurrentGlucoseStateProviding {
    /// Canonical glucose value in mg/dL (recommended internal canonical form).
    var glucoseMgdl: Double? { get }

    /// Canonical delta in mg/dL.
    var deltaMgdl: Double? { get }

    /// Canonical projected glucose in mg/dL.
    var projectedMgdl: Double? { get }

    /// Timestamp of the last reading/update.
    var updatedAt: Date? { get }

    /// Trend string / code from LoopFollow (we map to GlucoseSnapshot.Trend).
    var trendCode: String? { get }

    /// Secondary metrics (typically already unitless)
    var iob: Double? { get }
    var cob: Double? { get }
}

/// Builds a GlucoseSnapshot in the user’s preferred unit, without embedding provider logic.
enum GlucoseSnapshotBuilder {
    static func build(from provider: CurrentGlucoseStateProviding) -> GlucoseSnapshot? {
        guard
            let glucoseMgdl = provider.glucoseMgdl,
            glucoseMgdl > 0,
            let updatedAt = provider.updatedAt
        else {
            // Debug-only signal: we’re missing core state.
            // (If you prefer no logs here, remove this line.)
            LogManager.shared.log(
                category: .general,
                message: "GlucoseSnapshotBuilder: missing/invalid core values glucoseMgdl=\(provider.glucoseMgdl?.description ?? "nil") updatedAt=\(provider.updatedAt?.description ?? "nil")",
                isDebug: true
            )
            return nil
        }

        let preferredUnit = PreferredGlucoseUnit.snapshotUnit()

        let deltaMgdl = provider.deltaMgdl ?? 0.0

        let trend = mapTrend(provider.trendCode)

        // Not Looping — read from Observable, set by evaluateNotLooping() in DeviceStatus.swift
        let isNotLooping = Observable.shared.isNotLooping.value

        // Renewal overlay — show 30 minutes before the renewal deadline so the user
        // knows the LA is about to be replaced.
        let renewBy = Storage.shared.laRenewBy.value
        let showRenewalOverlay = renewBy > 0 && Date().timeIntervalSince1970 >= renewBy - 1800

        LogManager.shared.log(
            category: .general,
            message: "LA snapshot built: updatedAt=\(updatedAt) interval=\(updatedAt.timeIntervalSince1970)",
            isDebug: true
        )

        return GlucoseSnapshot(
            glucose: glucoseMgdl,
            delta: deltaMgdl,
            trend: trend,
            updatedAt: updatedAt,
            iob: provider.iob,
            cob: provider.cob,
            projected: provider.projectedMgdl,
            unit: preferredUnit,
            isNotLooping: isNotLooping,
            showRenewalOverlay: showRenewalOverlay
        )
    }

    private static func mapTrend(_ code: String?) -> GlucoseSnapshot.Trend {
        guard
            let raw = code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !raw.isEmpty
        else { return .unknown }

        // Common Nightscout strings:
        // "Flat", "FortyFiveUp", "SingleUp", "DoubleUp", "FortyFiveDown", "SingleDown", "DoubleDown"
        // Common variants:
        // "rising", "falling", "rapidRise", "rapidFall"

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
