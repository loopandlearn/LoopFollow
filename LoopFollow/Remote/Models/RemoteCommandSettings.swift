// LoopFollow
// RemoteCommandSettings.swift
// Created by codebymini.

import Foundation
import HealthKit

struct RemoteCommandSettings: Codable {
    let remoteType: RemoteType
    let user: String
    let sharedSecret: String
    let apnsKey: String
    let keyId: String
    let teamId: String?
    let maxBolus: Double
    let maxCarbs: Double
    let maxProtein: Double
    let maxFat: Double
    let mealWithBolus: Bool
    let mealWithFatProtein: Bool
    let productionEnvironment: Bool
    let loopAPNSQrCodeURL: String
    let version: String

    init(
        remoteType: RemoteType,
        user: String,
        sharedSecret: String,
        apnsKey: String,
        keyId: String,
        teamId: String?,
        maxBolus: Double,
        maxCarbs: Double,
        maxProtein: Double,
        maxFat: Double,
        mealWithBolus: Bool,
        mealWithFatProtein: Bool,
        productionEnvironment: Bool,
        loopAPNSQrCodeURL: String
    ) {
        self.remoteType = remoteType
        self.user = user
        self.sharedSecret = sharedSecret
        self.apnsKey = apnsKey
        self.keyId = keyId
        self.teamId = teamId
        self.maxBolus = maxBolus
        self.maxCarbs = maxCarbs
        self.maxProtein = maxProtein
        self.maxFat = maxFat
        self.mealWithBolus = mealWithBolus
        self.mealWithFatProtein = mealWithFatProtein
        self.productionEnvironment = productionEnvironment
        self.loopAPNSQrCodeURL = loopAPNSQrCodeURL
        version = "1.0"
    }

    /// Creates RemoteCommandSettings from the current Storage values
    static func fromCurrentStorage() -> RemoteCommandSettings {
        let storage = Storage.shared

        return RemoteCommandSettings(
            remoteType: storage.remoteType.value,
            user: storage.user.value,
            sharedSecret: storage.sharedSecret.value,
            apnsKey: storage.apnsKey.value,
            keyId: storage.keyId.value,
            teamId: storage.teamId.value,
            maxBolus: storage.maxBolus.value.doubleValue(for: .internationalUnit()),
            maxCarbs: storage.maxCarbs.value.doubleValue(for: .gram()),
            maxProtein: storage.maxProtein.value.doubleValue(for: .gram()),
            maxFat: storage.maxFat.value.doubleValue(for: .gram()),
            mealWithBolus: storage.mealWithBolus.value,
            mealWithFatProtein: storage.mealWithFatProtein.value,
            productionEnvironment: storage.productionEnvironment.value,
            loopAPNSQrCodeURL: storage.loopAPNSQrCodeURL.value
        )
    }

    /// Applies the settings to the current Storage
    func applyToStorage() {
        let storage = Storage.shared

        storage.remoteType.value = remoteType
        storage.user.value = user
        storage.sharedSecret.value = sharedSecret
        storage.apnsKey.value = apnsKey
        storage.keyId.value = keyId
        storage.teamId.value = teamId
        storage.maxBolus.value = HKQuantity(unit: .internationalUnit(), doubleValue: maxBolus)
        storage.maxCarbs.value = HKQuantity(unit: .gram(), doubleValue: maxCarbs)
        storage.maxProtein.value = HKQuantity(unit: .gram(), doubleValue: maxProtein)
        storage.maxFat.value = HKQuantity(unit: .gram(), doubleValue: maxFat)
        storage.mealWithBolus.value = mealWithBolus
        storage.mealWithFatProtein.value = mealWithFatProtein
        storage.productionEnvironment.value = productionEnvironment
        storage.loopAPNSQrCodeURL.value = loopAPNSQrCodeURL
    }

    /// Encodes the settings to a JSON string for QR code generation
    func encodeToJSON() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Decodes settings from a JSON string
    static func decodeFromJSON(_ jsonString: String) -> RemoteCommandSettings? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(RemoteCommandSettings.self, from: data)
        } catch {
            return nil
        }
    }

    /// Checks if the settings are valid for the given remote type
    func isValid() -> Bool {
        switch remoteType {
        case .none:
            return true
        case .nightscout:
            return !user.isEmpty
        case .trc:
            return !user.isEmpty && !sharedSecret.isEmpty && !apnsKey.isEmpty && !keyId.isEmpty
        case .loopAPNS:
            return !keyId.isEmpty && !apnsKey.isEmpty && teamId != nil && !loopAPNSQrCodeURL.isEmpty
        }
    }
}
