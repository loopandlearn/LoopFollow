// LoopFollow
// APNsCredentialValidator.swift

import Foundation

/// Validation rules for the APNs credentials the user pastes in
/// `APNSettingsView`. Used both by the settings UI to surface inline
/// errors and by `LiveActivitySettingsView` to warn when push-based
/// updates won't work.
enum APNsCredentialValidator {
    /// Apple Key IDs are exactly 10 uppercase alphanumeric characters.
    static func isValidKeyId(_ keyId: String) -> Bool {
        guard keyId.count == 10 else { return false }
        return keyId.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
    }

    /// A pasted .p8 must contain both PEM markers. We don't try to verify
    /// the inner base64 here — `LoopAPNSService.validateAndFixAPNSKey`
    /// already normalizes whitespace and logs deeper warnings, and we
    /// don't want to reject keys that JWTManager would happily sign.
    static func isValidApnsKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("-----BEGIN PRIVATE KEY-----")
            && trimmed.contains("-----END PRIVATE KEY-----")
    }

    /// Convenience for "is the user fully set up to send APNs pushes?"
    static func isFullyConfigured(keyId: String, apnsKey: String) -> Bool {
        isValidKeyId(keyId) && isValidApnsKey(apnsKey)
    }
}
