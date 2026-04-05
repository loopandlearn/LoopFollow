// LoopFollow
// FutureCarbsCondition.swift

import Foundation

/// Fires once when a future-dated carb entry's scheduled time arrives.
///
/// **How it works:**
/// 1. Each alarm tick scans `recentCarbs` for entries whose `date` is in the future.
///    New ones are added to a persistent "pending" list regardless of lookahead distance,
///    capturing the moment they were first observed (`observedAt`).
/// 2. When a pending entry's `carbDate` passes (i.e. `carbDate <= now`), verify the
///    carb still exists in `recentCarbs` **and** that the original distance
///    (`carbDate − observedAt`) was within the max lookahead window. If both hold,
///    fire the alarm. Otherwise silently remove the entry.
/// 3. Stale entries (observed > 2 hours ago) whose carb no longer exists in
///    `recentCarbs` are cleaned up automatically.
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

            // Must be in the future and meet the minimum grams threshold.
            // We track ALL future carbs (not just those within the lookahead
            // window) so that carbs originally outside the window cannot
            // drift in later with a fresh observedAt.
            guard carbTI > nowTI,
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
            let stillExists = data.recentCarbs.contains { carb in
                abs(carb.date.timeIntervalSince1970 - entry.carbDate) < tolerance
                    && carb.grams == entry.grams
            }

            // Cleanup stale entries (observed > 2 hours ago) only if
            // the carb no longer exists — prevents eviction and
            // re-observation with a fresh observedAt.
            if nowTI - entry.observedAt > 7200, !stillExists {
                return true
            }

            // Not yet due
            guard entry.carbDate <= nowTI else { return false }

            // Carb was deleted — remove silently
            if !stillExists { return true }

            // Carb was originally outside the lookahead window — remove without firing
            if entry.carbDate - entry.observedAt > maxLookaheadSec { return true }

            // Fire (one per tick)
            if !fired {
                fired = true
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
