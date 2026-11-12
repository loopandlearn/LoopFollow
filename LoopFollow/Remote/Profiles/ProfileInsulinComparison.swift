// LoopFollow
// ProfileInsulinComparison.swift

import Foundation

/// A schedule in which one set of profile values gives more insulin than another, and the times of day it does.
struct ProfileInsulinIncrease: Equatable, Identifiable {
    let kind: ProfileScheduleKind
    /// Start and end of each period, in seconds from midnight, end exclusive.
    let periods: [ClosedRange<Int>]

    var id: String { kind.rawValue }

    /// For example "Basal rates higher 06:00–09:00".
    var text: String {
        let times = periods.map { period -> String in
            if period.lowerBound == 0, period.upperBound == 86400 { return "all day" }
            let end = period.upperBound == 86400 ? "midnight" : ProfileValueFormat.timeText(period.upperBound)
            return "\(ProfileValueFormat.timeText(period.lowerBound))–\(end)"
        }
        return "\(kind.title) \(kind.moreInsulinWord) \(times.joined(separator: ", "))"
    }
}

/// Compares two sets of profile values by the insulin they lead to. Higher basal rates, lower carb ratios,
/// lower insulin sensitivities and a lower correction range all give more insulin.
enum ProfileInsulinComparison {
    static func increases(from old: TherapyProfileValues, to new: TherapyProfileValues) -> [ProfileInsulinIncrease] {
        ProfileScheduleKind.allCases.compactMap { kind in
            let periods = increasePeriods(kind, old: old, new: new)
            return periods.isEmpty ? nil : ProfileInsulinIncrease(kind: kind, periods: periods)
        }
    }

    /// Scheduled basal over a day before and after, when the day total rises.
    static func basalTotalIncrease(from old: TherapyProfileValues, to new: TherapyProfileValues) -> (old: Double, new: Double)? {
        let before = TherapyProfile.basalTotal(old.basal)
        let after = TherapyProfile.basalTotal(new.basal)
        return after > before + tolerance ? (before, after) : nil
    }

    private static let tolerance = 1e-6

    private static func increasePeriods(_ kind: ProfileScheduleKind, old: TherapyProfileValues, new: TherapyProfileValues) -> [ClosedRange<Int>] {
        let before = points(kind, in: old)
        let after = points(kind, in: new)
        guard !before.isEmpty, !after.isEmpty else { return [] }
        let times = Set(before.map(\.seconds) + after.map(\.seconds)).sorted()

        func value(_ points: [Point], at seconds: Int) -> Point {
            points.last { $0.seconds <= seconds } ?? points[0]
        }

        var periods: [ClosedRange<Int>] = []
        for (index, start) in times.enumerated() {
            let end = index + 1 < times.count ? times[index + 1] : 86400
            guard givesMoreInsulin(kind, old: value(before, at: start), new: value(after, at: start)) else { continue }
            if let last = periods.last, last.upperBound == start {
                periods[periods.count - 1] = last.lowerBound ... end
            } else {
                periods.append(start ... end)
            }
        }
        return periods
    }

    private struct Point {
        let seconds: Int
        let value: Double
        let high: Double
    }

    /// The schedule with glucose values in mg/dL, so profiles in different units compare correctly.
    private static func points(_ kind: ProfileScheduleKind, in values: TherapyProfileValues) -> [Point] {
        let glucoseFactor = TherapyProfileValues.normalizedUnits(values.units) == TherapyProfileValues.mgdl ? 1 : 18.01559
        switch kind {
        case .basal:
            return values.basal.map { Point(seconds: $0.seconds, value: $0.value, high: $0.value) }
        case .carbRatio:
            return values.carbRatio.map { Point(seconds: $0.seconds, value: $0.value, high: $0.value) }
        case .sensitivity:
            return values.sensitivity.map { Point(seconds: $0.seconds, value: $0.value * glucoseFactor, high: $0.value * glucoseFactor) }
        case .correctionRange:
            return values.target.map { Point(seconds: $0.seconds, value: $0.low * glucoseFactor, high: $0.high * glucoseFactor) }
        }
    }

    private static func givesMoreInsulin(_ kind: ProfileScheduleKind, old: Point, new: Point) -> Bool {
        func lower(_ a: Double, than b: Double) -> Bool { a < b - tolerance * max(1, abs(b)) }
        switch kind {
        case .basal:
            return lower(old.value, than: new.value)
        case .carbRatio, .sensitivity:
            return lower(new.value, than: old.value)
        case .correctionRange:
            return lower(new.value, than: old.value) || lower(new.high, than: old.high)
        }
    }
}

extension ProfileScheduleKind {
    /// The direction of this schedule's values that gives more insulin.
    var moreInsulinWord: String {
        self == .basal ? "higher" : "lower"
    }
}
