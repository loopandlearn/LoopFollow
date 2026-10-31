// LoopFollow
// RecommendedBolus.swift

import Foundation

/// The AID's latest bolus recommendation, offered only while no bolus came
/// after the loop cycle that calculated it. Until the next cycle, an earlier
/// recommendation leaves out that bolus, and using it could double it.
enum RecommendedBolus {
    static func current() -> (units: Double, at: TimeInterval)? {
        guard let units = Observable.shared.deviceRecBolus.value,
              let at = Observable.shared.deviceRecBolusAt.value
        else { return nil }
        if let lastBolus = lastBolusAt(), lastBolus >= at { return nil }
        return (units, at)
    }

    /// The latest manual bolus in Nightscout, or sent from LoopFollow or the
    /// watch, which Nightscout may not show yet. Automatic boluses are left
    /// out: the cycle that recommends a bolus can also give one.
    static func lastBolusAt() -> TimeInterval? {
        let nightscout = MainViewController.shared?.bolusData.map(\.date).max()
        let sentBolus = Storage.shared.remoteBolusHistory.value.map(\.date).max()
        let sentMeal = Storage.shared.remoteMealHistory.value.filter { $0.bolus > 0 }.map(\.date).max()
        let sent = [sentBolus, sentMeal].compactMap { $0?.timeIntervalSince1970 }.max()
        return [nightscout, sent].compactMap { $0 }.max()
    }
}
