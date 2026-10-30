// LoopFollow
// HubDeviceKey.swift

import Combine
import Foundation
import Security

/// Where the hub device key is kept.
protocol HubKeyStore {
    func load() -> String?
    /// False when the key was not stored.
    func save(_ key: String) -> Bool
    func delete()
}

/// The device key in the Keychain. It is readable after the first unlock, so pushes
/// and background tasks can use it, and never leaves this phone, not even in a backup,
/// so a phone restored from a backup does not share this device's identity at the hub.
struct HubKeychain: HubKeyStore {
    private static let service = "LoopFollowHub"
    /// The item: the device key, or `pendingUnregistration` for the key of a device this phone left.
    private let account: String

    init(account: String = "deviceKey") {
        self.account = account
    }

    static let pendingUnregistration = "pendingUnregistrationKey"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> String? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ key: String) -> Bool {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        if status != errSecSuccess {
            LogManager.shared.log(category: .hub, message: "Keychain save of the hub \(account) failed: \(status)")
        }
        return status == errSecSuccess
    }

    func delete() {
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.shared.log(category: .hub, message: "Keychain delete of the hub \(account) failed: \(status)")
        }
    }
}

/// The key this device authenticates to the hub with; empty while not connected.
/// A key kept in the app's defaults moves to the store once the store takes it.
/// Re-read after a launch before the first unlock, like the storage values.
final class HubDeviceKey: ObservableObject, BFUReloadable {
    @Published private(set) var value = ""

    /// The Keychain; a stand-in in tests, which run without a Keychain.
    var store: HubKeyStore
    private let legacy: StorageValue<String>

    init(store: HubKeyStore = HubKeychain(),
         legacy: StorageValue<String> = StorageValue(key: "hubDeviceKey", defaultValue: ""))
    {
        self.store = store
        self.legacy = legacy
        reload()
        StorageReadiness.register(self)
    }

    func reload() {
        let old = legacy.value
        if !old.isEmpty, store.save(old) {
            legacy.value = ""
            legacy.remove()
            LogManager.shared.log(category: .hub, message: "Hub device key moved to the Keychain")
        }
        let key = store.load() ?? legacy.value
        if key != value { value = key }
    }

    /// Stores a new key; throws when the store does not take it.
    func set(_ key: String) throws {
        guard store.save(key) else { throw HubClient.HubError.keyNotSaved }
        value = key
    }

    func clear() {
        store.delete()
        value = ""
    }
}

/// A device this phone left whose removal the hub has not confirmed: its key, kept like
/// the device key, and the hub's address. Kept until the hub removes the device or
/// answers that it no longer knows the key.
final class HubPendingUnregistration {
    /// The Keychain; a stand-in in tests.
    var store: HubKeyStore
    private let hubURL: StorageValue<String>

    init(store: HubKeyStore = HubKeychain(account: HubKeychain.pendingUnregistration),
         hubURL: StorageValue<String> = StorageValue(key: "hubPendingUnregistrationURL", defaultValue: ""))
    {
        self.store = store
        self.hubURL = hubURL
    }

    /// The key and hub address of the device to remove; nil when none is pending.
    var current: (key: String, hubURL: String)? {
        guard !hubURL.value.isEmpty, let key = store.load(), !key.isEmpty else { return nil }
        return (key, hubURL.value)
    }

    /// Keeps the device for removal; false when the key could not be stored.
    @discardableResult
    func keep(key: String, hubURL url: String) -> Bool {
        guard store.save(key) else { return false }
        hubURL.value = url
        return true
    }

    func clear() {
        store.delete()
        hubURL.value = ""
    }

    /// The hub removed the device (2xx), or no longer knows its key (401).
    static func isDone(_ code: Int) -> Bool {
        (200 ..< 300).contains(code) || code == 401
    }
}
