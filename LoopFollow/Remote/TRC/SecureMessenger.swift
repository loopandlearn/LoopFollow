// LoopFollow
// SecureMessenger.swift
// Created by Jonas Björkert.

import CryptoSwift
import Foundation
import Security

struct SecureMessenger {
    private let sharedKey: [UInt8]

    init?(sharedSecret: String) {
        guard let secretData = sharedSecret.data(using: .utf8) else {
            return nil
        }
        sharedKey = Array(secretData.sha256())
    }

    private func generateSecureRandomBytes(count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return status == errSecSuccess ? bytes : nil
    }

    func encrypt<T: Encodable>(_ object: T) throws -> String {
        let dataToEncrypt = try JSONEncoder().encode(object)

        guard let nonce = generateSecureRandomBytes(count: 12) else {
            throw NSError(domain: "SecureMessenger", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate secure random nonce."])
        }

        let gcm = GCM(iv: nonce, mode: .combined)
        let aes = try AES(key: sharedKey, blockMode: gcm, padding: .noPadding)
        let encryptedBytes = try aes.encrypt(Array(dataToEncrypt))
        let finalData = Data(nonce + encryptedBytes)

        return finalData.base64EncodedString()
    }
}
