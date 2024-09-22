//
//  Storage.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import HealthKit

class Storage {
    var remoteType = StorageValue<RemoteType>(key: "remoteType", default: .nightscout)
    var deviceToken = StorageValue<String>(key: "deviceToken", default: "")
    var sharedSecret = StorageValue<String>(key: "sharedSecret", default: "")
    var productionEnvironment = StorageValue<Bool>(key: "productionEnvironment", default: true)
    var token = StorageValue<String>(key: "token", default: "")
    var apnsKey = StorageValue<String>(key: "apnsKey", default: "")
    var teamId = StorageValue<String>(key: "teamId", default: "")
    var keyId = StorageValue<String>(key: "keyId", default: "")
    var bundleId = StorageValue<String>(key: "bundleId", default: "")
    var user = StorageValue<String>(key: "user", default: "")

    var maxBolus = SecureStorageValue<HKQuantity>(key: "maxBolus", default: HKQuantity(unit: .internationalUnit(), doubleValue: 1.0))
    var maxCarbs = SecureStorageValue<HKQuantity>(key: "maxCarbs", default: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxProtein = SecureStorageValue<HKQuantity>(key: "maxProtein", default: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxFat = SecureStorageValue<HKQuantity>(key: "maxFat", default: HKQuantity(unit: .gram(), doubleValue: 30.0))

    static let shared = Storage()

    private init() {
        if apnsKey.value.isEmpty && !token.value.isEmpty {
            apnsKey = token // Migrate the old `token` value to `apnsKey` TODO: Remove this code later on.
        }
    }
}
