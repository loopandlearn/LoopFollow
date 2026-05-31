// LoopFollow
// APNsCredentialValidator.swift

import Foundation

enum APNsCredentialValidator {
    static func isValidKeyId(_ keyId: String) -> Bool {
        let pattern = "^[A-Z0-9]{10}$"
        return keyId.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidApnsKey(_ apnsKey: String) -> Bool {
        apnsKey.contains("-----BEGIN PRIVATE KEY-----") &&
            apnsKey.contains("-----END PRIVATE KEY-----")
    }

    static func isFullyConfigured(keyId: String, apnsKey: String) -> Bool {
        isValidKeyId(keyId) && isValidApnsKey(apnsKey)
    }
}
