// LoopFollow
// ProfileEditLimits.swift

import Foundation

/// Decodes `T` when it can and leaves `value` nil otherwise, so a malformed optional block
/// does not fail the whole document.
struct LenientDecoded<T: Decodable>: Decodable {
    let value: T?

    init(_ value: T?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

/// The bounds Loop or Trio publishes in its profile document (`profileEditLimits`) for remotely edited profiles.
/// Glucose values and steps are in `units`. LoopFollow offers only values inside these bounds.
struct ProfileEditLimits: Decodable, Equatable {
    struct Range: Decodable, Equatable {
        let min: Double
        let max: Double
        let step: Double
        let recommendedMin: Double?
        let recommendedMax: Double?

        var isUsable: Bool {
            min.isFinite && max.isFinite && step.isFinite && step > 0 && min <= max && (max - min) / step <= 20000
        }

        /// Every value from `min` to `max` in steps of `step`, rounded to the step's decimals.
        var values: [Double] {
            guard isUsable else { return [] }
            let decimals = ProfileEditLimits.decimals(of: step)
            let count = Int(((max - min) / step + 1e-9).rounded(.down))
            return (0 ... count).map { ProfileEditLimits.round(min + Double($0) * step, decimals: decimals) }
        }

        func contains(_ value: Double) -> Bool {
            value >= min - ProfileEditLimits.tolerance && value <= max + ProfileEditLimits.tolerance
        }

        /// True when the value is inside the hard bounds but outside the recommended ones.
        func isOutsideRecommended(_ value: Double) -> Bool {
            if let recommendedMin, value < recommendedMin - ProfileEditLimits.tolerance { return true }
            if let recommendedMax, value > recommendedMax + ProfileEditLimits.tolerance { return true }
            return false
        }
    }

    static let tolerance = 1e-9

    let units: String
    let maxBasal: Double
    let basalRates: [Double]
    let basalMinimum: Double?
    let carbRatio: Range
    let sensitivity: Range
    let target: Range
    let maxSegments: Int
    /// The pump's basal schedule entry limit, when the app publishes one.
    let maxBasalSegments: Int?
    let segmentSeconds: Int

    /// Basal rates the editor offers: the supported rates up to max basal, from `basalMinimum` when set.
    var allowedBasalRates: [Double] {
        basalRates
            .filter { $0 <= maxBasal + Self.tolerance && $0 >= (basalMinimum ?? -.infinity) - Self.tolerance }
            .sorted()
    }

    func isAllowedBasalRate(_ rate: Double) -> Bool {
        allowedBasalRates.contains { abs($0 - rate) < Self.tolerance }
    }

    /// The most segments a schedule may have: the published maximum, never more than one per segment slot.
    var segmentLimit: Int {
        min(maxSegments, 86400 / segmentSeconds)
    }

    /// The most segments a schedule of `kind` may have; basal also stays within the pump's entry limit.
    func segmentLimit(for kind: ProfileScheduleKind) -> Int {
        guard kind == .basal, let maxBasalSegments else { return segmentLimit }
        return min(segmentLimit, maxBasalSegments)
    }

    /// False when the published limits are inconsistent; the editor is then disabled.
    var isUsable: Bool {
        segmentSeconds > 0 && 86400 % segmentSeconds == 0 && maxSegments > 0 && (maxBasalSegments ?? 1) > 0
            && !allowedBasalRates.isEmpty
            && carbRatio.isUsable && sensitivity.isUsable && target.isUsable
    }

    var normalizedUnits: String {
        TherapyProfileValues.normalizedUnits(units)
    }

    /// The number of decimals `step` needs, at most 4.
    static func decimals(of step: Double) -> Int {
        for decimals in 0 ... 4 {
            let scaled = step * pow(10, Double(decimals))
            if abs(scaled - scaled.rounded()) < 1e-6 { return decimals }
        }
        return 4
    }

    static func round(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10, Double(decimals))
        return (value * factor).rounded() / factor
    }
}

extension NSProfile {
    var editLimits: ProfileEditLimits? {
        profileEditLimits?.value
    }
}
