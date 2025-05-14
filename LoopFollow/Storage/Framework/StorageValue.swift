//
//  StorageValue.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Combine
import Foundation

class StorageValue<T: Codable & Equatable>: ObservableObject {
    let key: String

    @Published var value: T {
        didSet {
            guard value != oldValue else { return }

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
    }

    func remove() {
        StorageValue.defaults.removeObject(forKey: key)
    }
}
