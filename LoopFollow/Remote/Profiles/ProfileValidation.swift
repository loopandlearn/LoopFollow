// LoopFollow
// ProfileValidation.swift

import Foundation

/// The four schedules of a therapy profile.
enum ProfileScheduleKind: String, CaseIterable, Identifiable {
    case correctionRange
    case carbRatio
    case basal
    case sensitivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .correctionRange: return "Correction Range"
        case .carbRatio: return "Carb Ratios"
        case .basal: return "Basal Rates"
        case .sensitivity: return "Insulin Sensitivities"
        }
    }

    var isRange: Bool { self == .correctionRange }

    /// Correction ranges and insulin sensitivities are in the profile's glucose units.
    var isGlucose: Bool { self == .correctionRange || self == .sensitivity }

    func unitText(glucoseUnits: String) -> String {
        switch self {
        case .correctionRange: return glucoseUnits
        case .carbRatio: return "g/U"
        case .basal: return "U/hr"
        case .sensitivity: return "\(glucoseUnits)/U"
        }
    }

    /// The bounds for this schedule; nil for basal, which uses the list of supported rates.
    func range(in limits: ProfileEditLimits) -> ProfileEditLimits.Range? {
        switch self {
        case .correctionRange: return limits.target
        case .carbRatio: return limits.carbRatio
        case .sensitivity: return limits.sensitivity
        case .basal: return nil
        }
    }

    /// The values the editor offers, in ascending order.
    func options(in limits: ProfileEditLimits) -> [Double] {
        range(in: limits)?.values ?? limits.allowedBasalRates
    }

    func decimals(in limits: ProfileEditLimits) -> Int {
        if let range = range(in: limits) { return ProfileEditLimits.decimals(of: range.step) }
        return limits.allowedBasalRates.map(ProfileEditLimits.decimals(of:)).max() ?? 2
    }
}

/// How a value compares with the published limits.
enum ProfileValueStatus: Equatable {
    case ok
    /// Allowed, but outside the recommended range: shown as a warning.
    case outsideRecommended
    /// Outside the hard limits (or not a supported basal rate): the profile can not be sent.
    case notAllowed
}

extension ProfileEditLimits {
    func status(of value: Double, in kind: ProfileScheduleKind) -> ProfileValueStatus {
        guard value.isFinite else { return .notAllowed }
        guard let range = kind.range(in: self) else {
            return isAllowedBasalRate(value) ? .ok : .notAllowed
        }
        guard range.contains(value) else { return .notAllowed }
        return range.isOutsideRecommended(value) ? .outsideRecommended : .ok
    }

    /// Plain-language bounds for a schedule, for footers and messages.
    func boundsText(for kind: ProfileScheduleKind) -> String {
        let units = kind.unitText(glucoseUnits: normalizedUnits)
        let decimals = kind.decimals(in: self)
        func text(_ value: Double) -> String {
            Localizer.formatToLocalizedString(value, maxFractionDigits: max(decimals, 3), minFractionDigits: decimals)
        }
        guard let range = kind.range(in: self) else {
            let rates = allowedBasalRates
            return "Allowed: \(text(rates.first ?? 0))–\(text(rates.last ?? 0)) \(units), in the steps the pump supports."
        }
        var result = "Allowed: \(text(range.min))–\(text(range.max)) \(units)."
        if range.recommendedMin != nil || range.recommendedMax != nil {
            let low = range.recommendedMin.map(text) ?? text(range.min)
            let high = range.recommendedMax.map(text) ?? text(range.max)
            result += " Values outside \(low)–\(high) are unusual and shown in orange."
        }
        return result
    }
}

enum ProfileValidation {
    static let maxNameLength = 32
    /// The most profiles Loop and Trio keep, Default included.
    static let maxProfiles = 20

    /// Why another profile can not be created, or nil when it can.
    static func countProblem(profileCount: Int) -> String? {
        profileCount >= maxProfiles ? "There are already \(maxProfiles) profiles, the most the phone keeps. Delete a profile before creating another." : nil
    }

    /// The name as it is sent: surrounding spaces removed.
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Why `name` can not be used for a new or renamed profile, or nil when it can.
    /// `originalName` is the profile being renamed, which may keep its own name in another letter case.
    static func nameProblem(_ name: String, existingNames: [String], originalName: String? = nil) -> String? {
        let name = normalizedName(name)
        if name.isEmpty { return "Enter a name." }
        if name.count > maxNameLength { return "Use at most \(maxNameLength) characters." }
        if name.contains(".") { return "A name can't contain a period (.)." }
        if name.hasPrefix("$") { return "A name can't start with $." }
        if TherapyProfile.isDefaultName(name) { return "“Default” is the name of the Default profile. Choose another name." }
        let taken = existingNames.contains { existing in
            existing.caseInsensitiveCompare(name) == .orderedSame
                && existing != originalName
        }
        if taken { return "A profile with this name already exists." }
        return nil
    }

    /// Everything that keeps `values` from being sent within `limits`. Empty when the profile can be sent.
    static func problems(_ values: TherapyProfileValues, limits: ProfileEditLimits) -> [String] {
        var problems: [String] = []
        if values.units != limits.normalizedUnits {
            problems.append("The profile is in \(values.units), but the limits are in \(limits.normalizedUnits).")
        }
        let schedules: [(ProfileScheduleKind, [Int])] = [
            (.correctionRange, values.target.map(\.seconds)),
            (.carbRatio, values.carbRatio.map(\.seconds)),
            (.basal, values.basal.map(\.seconds)),
            (.sensitivity, values.sensitivity.map(\.seconds)),
        ]
        for (kind, starts) in schedules {
            problems += scheduleProblems(starts, kind: kind, limits: limits)
        }
        for (kind, items) in [(ProfileScheduleKind.carbRatio, values.carbRatio), (.basal, values.basal), (.sensitivity, values.sensitivity)] {
            if items.contains(where: { limits.status(of: $0.value, in: kind) == .notAllowed }) {
                problems.append("\(kind.title): a value is outside what is allowed. \(limits.boundsText(for: kind))")
            }
        }
        if values.target.contains(where: { limits.status(of: $0.low, in: .correctionRange) == .notAllowed || limits.status(of: $0.high, in: .correctionRange) == .notAllowed }) {
            problems.append("Correction Range: a value is outside what is allowed. \(limits.boundsText(for: .correctionRange))")
        }
        if values.target.contains(where: { $0.low > $0.high + ProfileEditLimits.tolerance }) {
            problems.append("Correction Range: the low value must not be above the high value.")
        }
        return problems
    }

    /// Everything that keeps `command` from being sent within `limits`. A save that keeps the values of the
    /// profile it updates (a pure rename) is not checked against the limits, which may have changed since the
    /// values were stored.
    static func problems(for command: ProfileCommand, limits: ProfileEditLimits) -> [String] {
        guard case let .save(_, original, values) = command else { return [] }
        if let original, original.values == values { return [] }
        return problems(values, limits: limits)
    }

    static func scheduleProblems(_ starts: [Int], kind: ProfileScheduleKind, limits: ProfileEditLimits) -> [String] {
        guard let first = starts.first else { return ["\(kind.title): add at least one time."] }
        var problems: [String] = []
        if first != 0 { problems.append("\(kind.title): the first time must be midnight.") }
        if zip(starts, starts.dropFirst()).contains(where: { $0 >= $1 }) {
            problems.append("\(kind.title): each time must be later than the one before.")
        }
        if starts.contains(where: { $0 < 0 || $0 >= 86400 || $0 % limits.segmentSeconds != 0 }) {
            problems.append("\(kind.title): times must be on the \(limits.segmentSeconds / 60)-minute grid.")
        }
        let segmentLimit = limits.segmentLimit(for: kind)
        if starts.count > segmentLimit {
            problems.append("\(kind.title): at most \(segmentLimit) times are allowed.")
        }
        return problems
    }
}
