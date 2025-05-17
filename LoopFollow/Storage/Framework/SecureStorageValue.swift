// LoopFollow
// SecureStorageValue.swift
// Created by Jonas Björkert on 2024-09-17.

import Combine
import Foundation

class SecureStorageValue<T: NSObject & NSSecureCoding & Equatable>: ObservableObject {
    let key: String

    @Published var value: T {
        didSet {
            guard value != oldValue else { return }
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
    }

    func remove() {
        SecureStorageValue.defaults.removeObject(forKey: key)
    }
}
