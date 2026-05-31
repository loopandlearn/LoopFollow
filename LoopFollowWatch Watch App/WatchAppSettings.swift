// LoopFollow
// WatchAppSettings.swift

import Combine
import Foundation

final class WatchAppSettings: ObservableObject {
    static let shared = WatchAppSettings()
    private init() {}

    // MARK: - App Group defaults

    private static let defaults = UserDefaults(suiteName: AppGroupID.current()) ?? .standard

    // MARK: - UserDefaults keys

    private enum Key {
        static let snoozeAllByDefault = "watchSnoozeAllByDefault"
        static let defaultSnoozeMinutes = "watchDefaultSnoozeMinutes"
        static func cooldown(_ type: WatchAlertType) -> String { "watchCooldown_\(type.rawValue)" }
    }

    // MARK: - Snooze defaults

    var snoozeAllByDefault: Bool {
        get { Self.defaults.object(forKey: Key.snoozeAllByDefault) as? Bool ?? true }
        set { Self.defaults.set(newValue, forKey: Key.snoozeAllByDefault); objectWillChange.send() }
    }

    var defaultSnoozeMinutes: Int {
        get { Self.defaults.object(forKey: Key.defaultSnoozeMinutes) as? Int ?? 60 }
        set { Self.defaults.set(newValue, forKey: Key.defaultSnoozeMinutes); objectWillChange.send() }
    }

    // MARK: - Cooldowns

    /// Default cooldowns in seconds. Used when no persisted value exists.
    static let defaultCooldowns: [WatchAlertType: TimeInterval] = [
        .lowBG: 15 * 60,
        .urgentLow: 5 * 60,
        .highBG: 15 * 60,
        .fastDrop: 10 * 60,
        .fastRise: 10 * 60,
    ]

    func cooldown(for type: WatchAlertType) -> TimeInterval {
        let stored = Self.defaults.double(forKey: Key.cooldown(type))
        return stored > 0 ? stored : (Self.defaultCooldowns[type] ?? 10 * 60)
    }

    func setCooldown(_ seconds: TimeInterval, for type: WatchAlertType) {
        Self.defaults.set(seconds, forKey: Key.cooldown(type))
        objectWillChange.send()
    }
}
