// LoopFollow
// DeviceStatusGrace.swift

import Foundation

/// How long the last known value of a device status field is kept after it stops arriving.
/// The info rows and the Live Activity both use this, so they always show the same thing.
enum DeviceStatusGrace {
    /// Matches the not-looping threshold.
    static let period: TimeInterval = 15 * 60

    /// Whether a value last received at `receivedAt` (seconds since 1970, 0 if never) is
    /// still within the grace period.
    static func isFresh(_ receivedAt: TimeInterval, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        receivedAt > 0 && now - receivedAt < period
    }
}
