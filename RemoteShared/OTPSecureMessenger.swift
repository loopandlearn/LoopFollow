// LoopFollow
// OTPSecureMessenger.swift

import CryptoKit
import Foundation

struct OTPSecureMessenger {
    private let encryptionKey: SymmetricKey

    /// Initialize with OTP code. The OTP code is hashed to create the encryption key.
    init?(otpCode: String) {
        guard let otpData = otpCode.data(using: .utf8) else {
            return nil
        }
        // Use SHA256 hash of OTP code as the encryption key
        let hashed = SHA256.hash(data: otpData)
        encryptionKey = SymmetricKey(data: hashed)
    }

    /// Encrypt an encodable object using AES-GCM with OTP-derived key
    func encrypt<T: Encodable>(_ object: T) throws -> String {
        let dataToEncrypt = try JSONEncoder().encode(object)

        // Generate a random nonce (12 bytes for GCM)
        let nonce = AES.GCM.Nonce()

        // Encrypt using AES-GCM
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: encryptionKey, nonce: nonce)

        // Format: nonce (12 bytes) + ciphertext + tag (16 bytes)
        let nonceData = Data(nonce)
        let ciphertext = sealedBox.ciphertext
        let tag = sealedBox.tag
        let combinedData = nonceData + ciphertext + tag

        return combinedData.base64EncodedString()
    }
}

/// Information needed to send a response notification back via APNS
struct ReturnNotificationInfo: Codable {
    let productionEnvironment: Bool
    let deviceToken: String
    let bundleId: String
    let teamId: String
    let keyId: String
    let apnsKey: String

    enum CodingKeys: String, CodingKey {
        case productionEnvironment = "production_environment"
        case deviceToken = "device_token"
        case bundleId = "bundle_id"
        case teamId = "team_id"
        case keyId = "key_id"
        case apnsKey = "apns_key"
    }
}
