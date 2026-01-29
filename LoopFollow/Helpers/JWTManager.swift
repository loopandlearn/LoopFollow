// LoopFollow
// JWTManager.swift

import Foundation
import SwiftJWT

struct JWTClaims: Claims {
    let iss: String
    let iat: Date
}

class JWTManager {
    static let shared = JWTManager()

    private init() {}

    func getOrGenerateJWT(keyId: String, teamId: String, apnsKey: String) -> String? {
        // 1. Check for a valid, non-expired JWT directly from Storage.shared
        if let jwt = Storage.shared.cachedJWT.value,
           let expiration = Storage.shared.jwtExpirationDate.value,
           Date() < expiration
        {
            return jwt
        }

        // 2. If no valid JWT is found, generate a new one
        let header = Header(kid: keyId)
        let claims = JWTClaims(iss: teamId, iat: Date())
        var jwt = JWT(header: header, claims: claims)

        do {
            let privateKey = Data(apnsKey.utf8)
            let jwtSigner = JWTSigner.es256(privateKey: privateKey)
            let signedJWT = try jwt.sign(using: jwtSigner)

            // 3. Save the new JWT and its expiration date directly to Storage.shared
            Storage.shared.cachedJWT.value = signedJWT
            Storage.shared.jwtExpirationDate.value = Date().addingTimeInterval(3600) // Expires in 1 hour

            return signedJWT
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to sign JWT: \(error.localizedDescription)")
            return nil
        }
    }

    // Invalidate the cache by clearing values in Storage.shared
    func invalidateCache() {
        Storage.shared.cachedJWT.value = nil
        Storage.shared.jwtExpirationDate.value = nil
    }
}
