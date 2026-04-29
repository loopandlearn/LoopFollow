// LoopFollow
// AppGroupID.swift

import Foundation

/// Resolves the App Group identifier in a PR-safe way.
///
/// Preferred contract:
/// - App Group = "group.<baseBundleIdentifier>"
/// - No team-specific hardcoding
///
/// Important nuance:
/// - Extensions often have a *different* bundle identifier than the main app.
/// - To keep app + extensions aligned, we:
///   1) Prefer an explicit base bundle id if provided via Info.plist key.
///   2) Otherwise, apply a conservative suffix-stripping heuristic.
///   3) Fall back to the current bundle identifier.
enum AppGroupID {
    /// Optional Info.plist key you can set in *both* app + extension targets
    /// to force a shared base bundle id (recommended for reliability).
    private static let baseBundleIDPlistKey = "LFAppGroupBaseBundleID"

    /// The base bundle identifier for the main app, with extension suffixes stripped.
    /// Usable from both the main app and extensions.
    static var baseBundleID: String {
        if let base = Bundle.main.object(forInfoDictionaryKey: baseBundleIDPlistKey) as? String,
           !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return base
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        return stripLikelyExtensionSuffixes(from: bundleID)
    }

    /// URL scheme derived from the bundle identifier. Works across app and extensions.
    /// Default build: "loopfollow", second: "loopfollow2", third: "loopfollow3", etc.
    static var urlScheme: String {
        let base = baseBundleID
        // Extract the suffix after "LoopFollow" in the bundle ID
        // e.g. "com.TEAM.LoopFollow2" → "2", "com.TEAM.LoopFollow" → ""
        if let range = base.range(of: "LoopFollow", options: .backwards) {
            let suffix = base[range.upperBound...]
            return "loopfollow\(suffix)"
        }
        return "loopfollow"
    }

    static func current() -> String {
        "group.\(baseBundleID)"
    }

    private static func stripLikelyExtensionSuffixes(from bundleID: String) -> String {
        let knownSuffixes = [
            ".LiveActivity",
            ".LiveActivityExtension",
            ".LoopFollowLAExtension",
            ".Widget",
            ".WidgetExtension",
            ".Widgets",
            ".WidgetsExtension",
            ".watchkitapp",
            ".Watch",
            ".WatchExtension",
            ".CarPlay",
            ".CarPlayExtension",
            ".Intents",
            ".IntentsExtension",
        ]

        for suffix in knownSuffixes {
            if bundleID.hasSuffix(suffix) {
                return String(bundleID.dropLast(suffix.count))
            }
        }

        return bundleID
    }
}
