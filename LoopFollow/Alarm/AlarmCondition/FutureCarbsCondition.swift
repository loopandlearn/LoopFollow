// LoopFollow
// FutureCarbsCondition.swift

import Foundation

/// Fires once when a future-dated carb entry's scheduled time arrives.
///
/// **How it works:**
/// 1. Each alarm tick scans `recentCarbs` for entries whose `date` is in the future
///    (within a configurable max lookahead window). New ones are added to a persistent
///    "pending" list.
/// 2. When a pending entry's `carbDate` passes (i.e. `carbDate <= now`), verify the
///    carb still exists in `recentCarbs`. If so, fire the alarm. If the carb was
///    deleted, silently remove it.
/// 3. Stale entries (observed > 2 hours ago) are cleaned up automatically.
struct FutureCarbsCondition: AlarmCondition {
    static let type: AlarmType = .futureCarbs
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        // ────────────────────────────────
        // 0. Pull settings
        // ────────────────────────────────
        let maxLookaheadMin = alarm.threshold ?? 45 // max lookahead in minutes
        let minGrams = alarm.delta ?? 5 // ignore carbs below this

        let nowTI = now.timeIntervalSince1970
        let maxLookaheadSec = maxLookaheadMin * 60

        var pending = Storage.shared.pendingFutureCarbs.value
        let tolerance: TimeInterval = 5 // seconds, for matching carb entries

        // ────────────────────────────────
        // 1. Scan for new future carbs
        // ────────────────────────────────
        for carb in data.recentCarbs {
            let carbTI = carb.date.timeIntervalSince1970

            // Must be in the future and within the lookahead window
            guard carbTI > nowTI,
                  carbTI - nowTI <= maxLookaheadSec,
                  carb.grams >= minGrams
            else { continue }

            // Already tracked?
            let alreadyTracked = pending.contains { entry in
                abs(entry.carbDate - carbTI) < tolerance && entry.grams == carb.grams
            }
            if !alreadyTracked {
                pending.append(PendingFutureCarb(
                    carbDate: carbTI,
                    grams: carb.grams,
                    observedAt: nowTI
                ))
            }
        }

        // ────────────────────────────────
        // 2. Check if any pending entry is due
        // ────────────────────────────────
        var fired = false

        pending.removeAll { entry in
            // Cleanup stale entries (observed > 2 hours ago)
            if nowTI - entry.observedAt > 7200 {
                return true
            }

            // Not yet due
            guard entry.carbDate <= nowTI else { return false }

            // Due — verify carb still exists in recentCarbs
            let stillExists = data.recentCarbs.contains { carb in
                abs(carb.date.timeIntervalSince1970 - entry.carbDate) < tolerance
                    && carb.grams == entry.grams
            }

            if stillExists, !fired {
                fired = true
                return true // remove from pending after firing
            }

            // Carb was deleted or we already fired this tick — remove silently
            if !stillExists {
                return true
            }

            return false
        }

        // ────────────────────────────────
        // 3. Persist and return
        // ────────────────────────────────
        Storage.shared.pendingFutureCarbs.value = pending
        return fired
    }
}
