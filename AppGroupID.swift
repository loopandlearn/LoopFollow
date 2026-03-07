//
//  AppGroupID.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-24.
//

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

    static func current() -> String {
        if let base = Bundle.main.object(forInfoDictionaryKey: baseBundleIDPlistKey) as? String,
           !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "group.\(base)"
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"

        // Heuristic: strip common extension suffixes so the extension can land on the main app’s group id.
        let base = stripLikelyExtensionSuffixes(from: bundleID)

        return "group.\(base)"
    }

    private static func stripLikelyExtensionSuffixes(from bundleID: String) -> String {
        let knownSuffixes = [
            ".LiveActivity",
            ".LiveActivityExtension",
            ".Widget",
            ".WidgetExtension",
            ".Widgets",
            ".WidgetsExtension",
            ".Watch",
            ".WatchExtension",
            ".CarPlay",
            ".CarPlayExtension",
            ".Intents",
            ".IntentsExtension"
        ]

        for suffix in knownSuffixes {
            if bundleID.hasSuffix(suffix) {
                return String(bundleID.dropLast(suffix.count))
            }
        }

        return bundleID
    }
}