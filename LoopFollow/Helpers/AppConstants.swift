// LoopFollow
// AppConstants.swift

import Foundation

/// Class that contains general constants used in different classes
class AppConstants {
    static let APP_GROUP_ID = "group.com.$(unique_id).LoopFollow"

    /// Extracts the app suffix from the bundle identifier
    /// Bundle identifier format: com.$(unique_id).LoopFollow$(app_suffix)
    /// Returns the suffix part (e.g., "2" for "com.example.LoopFollow2")
    static var appSuffix: String {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            return ""
        }

        // Extract suffix from bundle identifier
        // Pattern: com.$(unique_id).LoopFollow$(app_suffix)
        let pattern = "LoopFollow(.+)$"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: bundleId.utf16.count)
            if let match = regex.firstMatch(in: bundleId, options: [], range: range) {
                let suffixRange = match.range(at: 1)
                if let swiftRange = Range(suffixRange, in: bundleId) {
                    let suffix = String(bundleId[swiftRange])
                    return suffix.isEmpty ? "" : "_\(suffix)"
                }
            }
        }

        return ""
    }

    /// Returns a unique identifier for this app instance based on the app suffix
    static var appInstanceId: String {
        return "LoopFollow\(appSuffix)"
    }
}
