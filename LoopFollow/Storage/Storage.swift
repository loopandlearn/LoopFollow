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
    var remoteType = StorageValue<RemoteType>(key: "remoteType", defaultValue: .nightscout)
    var deviceToken = StorageValue<String>(key: "deviceToken", defaultValue: "")
    var expirationDate = StorageValue<Date?>(key: "expirationDate", defaultValue: nil)
    var sharedSecret = StorageValue<String>(key: "sharedSecret", defaultValue: "")
    var productionEnvironment = StorageValue<Bool>(key: "productionEnvironment", defaultValue: true)
    var apnsKey = StorageValue<String>(key: "apnsKey", defaultValue: "")
    var teamId = StorageValue<String?>(key: "teamId", defaultValue: nil)
    var keyId = StorageValue<String>(key: "keyId", defaultValue: "")
    var bundleId = StorageValue<String>(key: "bundleId", defaultValue: "")
    var user = StorageValue<String>(key: "user", defaultValue: "")

    var maxBolus = SecureStorageValue<HKQuantity>(key: "maxBolus", defaultValue: HKQuantity(unit: .internationalUnit(), doubleValue: 1.0))
    var maxCarbs = SecureStorageValue<HKQuantity>(key: "maxCarbs", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxProtein = SecureStorageValue<HKQuantity>(key: "maxProtein", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxFat = SecureStorageValue<HKQuantity>(key: "maxFat", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))

    var mealWithBolus = StorageValue<Bool>(key: "mealWithBolus", defaultValue: false)
    var mealWithFatProtein = StorageValue<Bool>(key: "mealWithFatProtein", defaultValue: false)

    var cachedJWT = StorageValue<String?>(key: "cachedJWT", defaultValue: nil)
    var jwtExpirationDate = StorageValue<Date?>(key: "jwtExpirationDate", defaultValue: nil)

    var backgroundRefreshType = StorageValue<BackgroundRefreshType>(key: "backgroundRefreshType", defaultValue: .silentTune)

    var selectedBLEDevice = StorageValue<BLEDevice?>(key: "selectedBLEDevice", defaultValue: nil)

    var debugLogLevel = StorageValue<Bool>(key: "debugLogLevel", defaultValue: false)

    var contactTrend = StorageValue<ContactIncludeOption>(key: "contactTrend", defaultValue: .off)
    var contactDelta = StorageValue<ContactIncludeOption>(key: "contactDelta", defaultValue: .off)
    var contactEnabled = StorageValue<Bool>(key: "contactEnabled", defaultValue: false)
    var contactBackgroundColor = StorageValue<String>(key: "contactBackgroundColor", defaultValue: ContactColorOption.black.rawValue)
    var contactTextColor = StorageValue<String>(key: "contactTextColor", defaultValue: ContactColorOption.white.rawValue)
    
    var sensorScheduleOffset = StorageValue<Double?>(key: "sensorScheduleOffset", defaultValue: nil)

    var alarms = StorageValue<[Alarm]>(key: "alarms", defaultValue: [])
    var alarmConfiguration = StorageValue<AlarmConfiguration>(
        key: "alarmConfiguration",
        defaultValue: .default
    )

    static let shared = Storage()

    private init() { }
}
