// LoopFollow
// WatchKeychain.swift

import Foundation
import Security

/// Stores the credentials from the phone in the watch's Keychain. Items are
/// readable after the first unlock and never leave this watch, not even in a backup.
enum WatchKeychain {
    private static let service = "LoopFollowWatch"
    private static let account = "credentials"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func save(_ credentials: WatchCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        if status != errSecSuccess {
            LogManager.shared.log(category: .general, message: "Keychain save failed: \(status)")
        }
    }

    static func load() -> WatchCredentials? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(WatchCredentials.self, from: data)
    }
}
