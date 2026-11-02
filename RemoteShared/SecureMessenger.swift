// LoopFollow
// SecureMessenger.swift

import CryptoKit
import Foundation

struct SecureMessenger {
    private let encryptionKey: SymmetricKey

    init?(sharedSecret: String) {
        guard let secretData = sharedSecret.data(using: .utf8) else {
            return nil
        }
        let hashed = SHA256.hash(data: secretData)
        encryptionKey = SymmetricKey(data: hashed)
    }

    func encrypt<T: Encodable>(_ object: T) throws -> String {
        let dataToEncrypt = try JSONEncoder().encode(object)

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: encryptionKey, nonce: nonce)

        let combinedData = Data(nonce) + sealedBox.ciphertext + sealedBox.tag

        return combinedData.base64EncodedString()
    }
}
