// LoopFollow
// SecureStorageValue.swift

import Combine
import Foundation

class SecureStorageValue<T: NSObject & NSSecureCoding & Equatable>: ObservableObject, BFUReloadable {
    let key: String

    @Published var value: T {
        didSet {
            guard value != oldValue else { return }
            // Memory-only during a suspect BFU window; see StorageValue's guard.
            guard !StorageReadiness.isSuppressingWrites else {
                StorageReadiness.noteSuppressedWrite(key: key)
                return
            }
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) {
                SecureStorageValue.defaults.set(data, forKey: key)
            }
        }
    }

    var exists: Bool {
        return SecureStorageValue.defaults.object(forKey: key) != nil
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    init(key: String, defaultValue: T) {
        self.key = key
        if let data = SecureStorageValue.defaults.data(forKey: key),
           let decodedValue = try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
        {
            value = decodedValue
        } else {
            value = defaultValue
        }

        StorageReadiness.register(self)
    }

    func remove() {
        SecureStorageValue.defaults.removeObject(forKey: key)
    }

    /// Re-reads from UserDefaults during BFU recovery. Same class-C backing as
    /// StorageValue, so it recovers identically.
    func reload() {
        if let data = SecureStorageValue.defaults.data(forKey: key),
           let decodedValue = try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data),
           decodedValue != value
        {
            value = decodedValue
        }
    }
}
