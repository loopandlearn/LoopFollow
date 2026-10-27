// LoopFollow
// WatchCommandValidator.swift

import Foundation

/// The guardrails for a watch command, applied by the phone before it sends
/// one and by the watch before it sends one directly. Same limits and messages
/// as the phone's Remote screens.
enum WatchCommandValidator {
    struct Limits: Equatable {
        var maxBolus: Double
        var bolusIncrement: Double
        var maxCarbs: Double
        var maxFat: Double
        var maxProtein: Double
        var mealWithBolus: Bool
        var mealWithFatProtein: Bool
    }

    /// Loop rejects carb entries outside this window; same limits as LoopAPNSCarbsView.
    static let loopMaxPastHours: Double = 12
    static let loopMaxFutureHours: Double = 1
    /// Loop's default absorption time for a remote carb entry, in hours.
    static let loopAbsorptionHours = 3.0

    /// Returns the action to send (Trio boluses rounded down to the increment) or the reason it is refused.
    static func validate(
        _ action: WatchCommand.Action,
        kind: WatchRemoteConfig.Kind,
        limits: Limits,
        now: Date = Date()
    ) -> Result<WatchCommand.Action, ValidationError> {
        switch (kind, action) {
        case let (.loop, .bolus(units)):
            guard units > 0 else { return .failure(ValidationError("Enter an amount above zero.")) }
            guard units <= limits.maxBolus else { return .failure(ValidationError(exceedsMaxBolus(units, limits))) }
            return .success(action)

        case let (.trio, .bolus(units)):
            let stepped = roundedToStep(units, step: limits.bolusIncrement)
            guard stepped > 0 else { return .failure(ValidationError("Enter an amount above zero.")) }
            guard stepped <= limits.maxBolus else { return .failure(ValidationError(exceedsMaxBolus(stepped, limits))) }
            return .success(.bolus(units: stepped))

        case let (.loop, .meal(carbs, fat, protein, bolus, consumedAt)):
            guard fat == 0, protein == 0, bolus == 0 else { return .failure(ValidationError("Loop accepts carbs only from the watch.")) }
            guard carbs > 0 else { return .failure(ValidationError("Enter an amount above zero.")) }
            guard carbs <= limits.maxCarbs else { return .failure(ValidationError(exceeds("Carbs", carbs, limits.maxCarbs))) }
            guard consumedAt >= now.addingTimeInterval(-loopMaxPastHours * 3600) else {
                return .failure(ValidationError("Time must be within the prior \(Int(loopMaxPastHours)) hours."))
            }
            guard consumedAt <= now.addingTimeInterval(loopMaxFutureHours * 3600) else {
                return .failure(ValidationError("Time must be within the next \(Int(loopMaxFutureHours)) hour."))
            }
            return .success(action)

        case let (.trio, .meal(carbs, fat, protein, bolus, consumedAt)):
            guard limits.mealWithFatProtein || (fat == 0 && protein == 0) else {
                return .failure(ValidationError("Meal with Fat/Protein is turned off in LoopFollow's Remote settings."))
            }
            guard limits.mealWithBolus || bolus == 0 else {
                return .failure(ValidationError("Meal with Bolus is turned off in LoopFollow's Remote settings."))
            }
            guard carbs >= 0, fat >= 0, protein >= 0, carbs > 0 || fat > 0 || protein > 0 else {
                return .failure(ValidationError("Enter carbs, fat or protein."))
            }
            guard carbs <= limits.maxCarbs else { return .failure(ValidationError(exceeds("Carbs", carbs, limits.maxCarbs))) }
            guard fat <= limits.maxFat else { return .failure(ValidationError(exceeds("Fat", fat, limits.maxFat))) }
            guard protein <= limits.maxProtein else { return .failure(ValidationError(exceeds("Protein", protein, limits.maxProtein))) }
            let steppedBolus = roundedToStep(bolus, step: limits.bolusIncrement)
            guard steppedBolus <= limits.maxBolus else { return .failure(ValidationError(exceedsMaxBolus(steppedBolus, limits))) }
            return .success(.meal(carbs: carbs, fat: fat, protein: protein, bolus: steppedBolus, consumedAt: consumedAt))

        case (.loop, .startTempTarget), (.loop, .cancelTempTarget):
            return .failure(ValidationError("Temp targets are not available for Loop."))

        default:
            return .success(action)
        }
    }

    /// Rounds down to the bolus increment, as the phone's Trio bolus screen does.
    static func roundedToStep(_ value: Double, step: Double) -> Double {
        let step = max(0.001, step)
        let stepped = ((value / step) + 1e-10).rounded(.down) * step
        return (stepped * 1000).rounded() / 1000
    }

    private static func exceedsMaxBolus(_ units: Double, _ limits: Limits) -> String {
        "\(format(units)) U exceeds the maximum bolus of \(format(limits.maxBolus)) U set in LoopFollow."
    }

    private static func exceeds(_ what: String, _ grams: Double, _ max: Double) -> String {
        "\(what) (\(Int(grams)) g) exceeds the maximum of \(Int(max)) g set in LoopFollow."
    }

    private static func format(_ units: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 3
        return nf.string(from: NSNumber(value: units)) ?? "\(units)"
    }

    struct ValidationError: Error, Equatable {
        let message: String

        init(_ message: String) {
            self.message = message
        }
    }
}

extension WatchCommand {
    /// Trio treats a missing time as now; within a minute of now counts as now, as in the phone's meal screen.
    static func trioScheduledTime(_ consumedAt: Date, now: Date = Date()) -> Date? {
        abs(consumedAt.timeIntervalSince(now)) < 60 ? nil : consumedAt.dateUsingCurrentSeconds()
    }
}

extension WatchRemoteConfig {
    /// The phone's guardrails as last sent to the watch.
    var limits: WatchCommandValidator.Limits {
        WatchCommandValidator.Limits(
            maxBolus: maxBolus,
            bolusIncrement: bolusIncrement,
            maxCarbs: maxCarbs,
            maxFat: maxFat,
            maxProtein: maxProtein,
            mealWithBolus: mealWithBolus,
            mealWithFatProtein: mealWithFatProtein
        )
    }
}
