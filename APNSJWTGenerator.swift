// APNSJWTGenerator.swift
// Philippe Achkar
// 2026-03-07

import Foundation
import CryptoKit

struct APNSJWTGenerator {

    // MARK: - Configuration (read from Info.plist — never hardcoded)

    static var keyID: String {
        Bundle.main.infoDictionary?["APNSKeyID"] as? String ?? ""
    }

    static var teamID: String {
        Bundle.main.infoDictionary?["APNSTeamID"] as? String ?? ""
    }

    // MARK: - JWT Generation

    /// Generates a signed ES256 JWT for APNs authentication.
    /// Valid for 60 minutes per Apple's requirements.
    static func generateToken() throws -> String {
        let privateKey = try loadPrivateKey()
        let header = try encodeHeader()
        let payload = try encodePayload()
        let signingInput = "\(header).\(payload)"

        guard let signingData = signingInput.data(using: .utf8) else {
            throw APNSJWTError.encodingFailed
        }

        let signature = try privateKey.signature(for: signingData)
        let signatureBase64 = base64URLEncode(signature.rawRepresentation)
        return "\(signingInput).\(signatureBase64)"
    }

    // MARK: - Private Helpers

    private static func loadPrivateKey() throws -> P256.Signing.PrivateKey {
        guard !keyID.isEmpty else {
            throw APNSJWTError.keyIDNotConfigured
        }
        guard let keyURL = Bundle.main.url(forResource: "AuthKey_\(keyID)", withExtension: "p8") else {
            throw APNSJWTError.keyFileNotFound
        }
        let keyString = try String(contentsOf: keyURL, encoding: .utf8)
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let keyData = Data(base64Encoded: keyString) else {
            throw APNSJWTError.keyDecodingFailed
        }

        return try P256.Signing.PrivateKey(derRepresentation: keyData)
    }

    private static func encodeHeader() throws -> String {
        let header: [String: String] = [
            "alg": "ES256",
            "kid": keyID
        ]
        let data = try JSONSerialization.data(withJSONObject: header)
        return base64URLEncode(data)
    }

    private static func encodePayload() throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": teamID,
            "iat": now
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return base64URLEncode(data)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Errors

enum APNSJWTError: Error, LocalizedError {
    case keyIDNotConfigured
    case keyFileNotFound
    case keyDecodingFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .keyIDNotConfigured:
            return "APNSKeyID not set in Info.plist."
        case .keyFileNotFound:
            return "APNs p8 key file not found in app bundle. Add AuthKey_\(APNSJWTGenerator.keyID).p8 to the project."
        case .keyDecodingFailed:
            return "Failed to decode APNs p8 key."
        case .encodingFailed:
            return "Failed to encode JWT signing input."
        }
    }
}
