//
//  GlucoseLiveActivityAttributes.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-24.
//

import ActivityKit
import Foundation

struct GlucoseLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// The latest snapshot, already converted into the user’s preferred unit.
        let snapshot: GlucoseSnapshot

        /// Monotonic sequence for “did we update?” debugging and hung detection.
        let seq: Int

        /// Reason the app refreshed (e.g., "bg", "deviceStatus").
        let reason: String

        /// When the activity state was produced.
        let producedAt: Date
    }

    /// Reserved for future metadata. Keep minimal for stability.
    let title: String
}