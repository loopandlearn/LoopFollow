// LoopFollow
// StorageValue.swift

import Combine
import Foundation

class StorageValue<T: Codable & Equatable>: ObservableObject, BFUReloadable {
    let key: String

    @Published var value: T {
        didSet {
            guard value != oldValue else { return }

            // Suspect BFU: keep in memory only — a poisoned-default write could be
            // flushed over real data on unlock. Hydration reconciles from disk.
            guard !StorageReadiness.isSuppressingWrites else {
                StorageReadiness.noteSuppressedWrite(key: key)
                return
            }

            if let encodedData = try? JSONEncoder().encode(value) {
                StorageValue.defaults.set(encodedData, forKey: key)
            }
        }
    }

    var exists: Bool {
        return StorageValue.defaults.object(forKey: key) != nil
    }

    private static var defaults: UserDefaults {
        return UserDefaults.standard
    }

    init(key: String, defaultValue: T) {
        self.key = key

        if let data = StorageValue.defaults.data(forKey: key),
           let decodedValue = try? JSONDecoder().decode(T.self, from: data)
        {
            value = decodedValue
        } else {
            value = defaultValue
        }

        StorageReadiness.register(self)
    }

    func remove() {
        StorageValue.defaults.removeObject(forKey: key)
    }

    /// Re-reads the value from UserDefaults, updating the @Published cache.
    /// Call this when the app foregrounds after a Before-First-Unlock background launch,
    /// where StorageValue was initialized while UserDefaults was locked (returning defaults).
    func reload() {
        if let data = StorageValue.defaults.data(forKey: key),
           let decodedValue = try? JSONDecoder().decode(T.self, from: data),
           decodedValue != value
        {
            value = decodedValue
        }
    }
}
