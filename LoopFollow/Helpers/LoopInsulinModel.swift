// LoopFollow
// LoopInsulinModel.swift

import Foundation

/// The exponential insulin curves Loop offers, with LoopKit's
/// `ExponentialInsulinModelPreset` durations, peaks and delay.
enum LoopInsulinModel: String, CaseIterable, Codable {
    case rapidActingAdult
    case rapidActingChild
    case fiasp
    case lyumjev
    case afrezza

    var displayName: String {
        switch self {
        case .rapidActingAdult: return "Rapid-Acting – Adults"
        case .rapidActingChild: return "Rapid-Acting – Children"
        case .fiasp: return "Fiasp"
        case .lyumjev: return "Lyumjev"
        case .afrezza: return "Afrezza"
        }
    }

    /// Duration of the curve, excluding the delay.
    var actionDuration: TimeInterval {
        switch self {
        case .afrezza: return 300 * 60
        default: return 360 * 60
        }
    }

    /// Time of peak activity, counted from the end of the delay.
    var peakActivity: TimeInterval {
        switch self {
        case .rapidActingAdult: return 75 * 60
        case .rapidActingChild: return 65 * 60
        case .fiasp, .lyumjev: return 55 * 60
        case .afrezza: return 29 * 60
        }
    }

    var delay: TimeInterval { 10 * 60 }

    /// Time from delivery until a dose has no effect left.
    var effectDuration: TimeInterval { actionDuration + delay }

    private var terms: (tau: Double, a: Double, s: Double) {
        let td = actionDuration
        let tp = peakActivity
        let tau = tp * (1 - tp / td) / (1 - 2 * tp / td)
        let a = 2 * tau / td
        let s = 1 / (1 - a + (1 + a) * exp(-td / tau))
        return (tau, a, s)
    }

    /// Fraction of a dose still to act, `time` after delivery (insulin on board).
    func percentEffectRemaining(at time: TimeInterval) -> Double {
        let t = time - delay
        if t <= 0 { return 1 }
        if t >= actionDuration { return 0 }
        let (tau, a, s) = terms
        let td = actionDuration
        return 1 - s * (1 - a) * ((t * t / (tau * td * (1 - a)) - t / tau - 1) * exp(-t / tau) + 1)
    }

    /// Fraction of a dose acting per hour, `time` after delivery: the rate at
    /// which `percentEffectRemaining` falls.
    func activity(at time: TimeInterval) -> Double {
        let t = time - delay
        guard t > 0, t < actionDuration else { return 0 }
        let (tau, _, s) = terms
        return s / (tau * tau) * t * (1 - t / actionDuration) * exp(-t / tau) * 3600
    }
}
