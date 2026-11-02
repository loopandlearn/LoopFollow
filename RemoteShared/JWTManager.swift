// LoopFollow
// JWTManager.swift

import CryptoKit
import Foundation

class JWTManager {
    static let shared = JWTManager()

    private struct CachedToken {
        let jwt: String
        let expiresAt: Date
    }

    /// Cache keyed by "keyId:teamId", 55 min TTL
    private var cache: [String: CachedToken] = [:]
    private let ttl: TimeInterval = 55 * 60
    private let lock = NSLock()

    private init() {}

    func getOrGenerateJWT(keyId: String, teamId: String, apnsKey: String) -> String? {
        let cacheKey = "\(keyId):\(teamId)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[cacheKey], Date() < cached.expiresAt {
            return cached.jwt
        }

        do {
            let privateKey = try loadPrivateKey(from: apnsKey)
            let header = try encodeHeader(keyId: keyId)
            let payload = try encodePayload(teamId: teamId)
            let signingInput = "\(header).\(payload)"

            guard let signingData = signingInput.data(using: .utf8) else {
                LogManager.shared.log(category: .apns, message: "Failed to encode JWT signing input")
                return nil
            }

            let signature = try privateKey.signature(for: signingData)
            let signatureBase64 = base64URLEncode(signature.rawRepresentation)
            let signedJWT = "\(signingInput).\(signatureBase64)"

            cache[cacheKey] = CachedToken(jwt: signedJWT, expiresAt: Date().addingTimeInterval(ttl))
            LogManager.shared.log(category: .apns, message: "JWT generated for key \(LogRedactor.keyId(keyId)) (TTL 55 min)")
            return signedJWT
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to sign JWT: \(error.localizedDescription)")
            return nil
        }
    }

    func invalidateCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        LogManager.shared.log(category: .apns, message: "JWT cache invalidated")
    }

    // MARK: - Private Helpers

    private func loadPrivateKey(from apnsKey: String) throws -> P256.Signing.PrivateKey {
        let cleaned = apnsKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let keyData = Data(base64Encoded: cleaned) else {
            throw JWTError.keyDecodingFailed
        }

        return try P256.Signing.PrivateKey(derRepresentation: keyData)
    }

    private func encodeHeader(keyId: String) throws -> String {
        let header: [String: String] = [
            "alg": "ES256",
            "kid": keyId,
        ]
        let data = try JSONSerialization.data(withJSONObject: header)
        return base64URLEncode(data)
    }

    private func encodePayload(teamId: String) throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": teamId,
            "iat": now,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return base64URLEncode(data)
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private enum JWTError: Error, LocalizedError {
        case keyDecodingFailed

        var errorDescription: String? {
            switch self {
            case .keyDecodingFailed:
                return "Failed to decode APNs p8 key content. Ensure it is valid base64."
            }
        }
    }
}
