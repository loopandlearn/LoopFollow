// LoopFollow
// PendingFutureCarb.swift

import Foundation

/// Tracks a future-dated carb entry that has been observed but whose scheduled time
/// has not yet arrived. Used by `FutureCarbsCondition` to fire a reminder when it's time to eat.
struct PendingFutureCarb: Codable, Equatable {
    /// Scheduled eating time (`timeIntervalSince1970`)
    let carbDate: TimeInterval

    /// Grams of carbs (used together with `carbDate` to identify unique entries)
    let grams: Double

    /// When the entry was first observed (`timeIntervalSince1970`, for staleness cleanup)
    let observedAt: TimeInterval
}
