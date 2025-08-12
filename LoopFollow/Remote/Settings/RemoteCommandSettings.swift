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
    let url: String
    let token: String
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
        loopAPNSQrCodeURL: String,
        url: String,
        token: String
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
        self.url = url
        self.token = token
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
            loopAPNSQrCodeURL: storage.loopAPNSQrCodeURL.value,
            url: storage.url.value,
            token: storage.token.value
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
        storage.url.value = url
        storage.token.value = token
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

    /// Validates URL and token compatibility with current storage
    /// Returns a tuple with (isCompatible, shouldPromptForURL, shouldPromptForToken, message)
    func validateCompatibilityWithCurrentStorage() -> (isCompatible: Bool, shouldPromptForURL: Bool, shouldPromptForToken: Bool, message: String) {
        let storage = Storage.shared
        let currentURL = storage.url.value
        let currentToken = storage.token.value

        var shouldPromptForURL = false
        var shouldPromptForToken = false
        var message = ""

        // Check if current user has URL set
        let hasCurrentURL = !currentURL.isEmpty
        let hasCurrentToken = !currentToken.isEmpty

        // Check if scanned settings have URL/token
        let hasScannedURL = !url.isEmpty
        let hasScannedToken = !token.isEmpty

        // If current user doesn't have URL but scanned settings do, prompt to set it
        if !hasCurrentURL, hasScannedURL {
            shouldPromptForURL = true
            message = "The scanned settings include a Nightscout URL. Would you like to set this as your Nightscout address?"
        }

        // If current user doesn't have token but scanned settings do, prompt to set it
        if !hasCurrentToken, hasScannedToken {
            shouldPromptForToken = true
            if !message.isEmpty {
                message += "\n\nThe scanned settings also include a token. Would you like to set this as your access token?"
            } else {
                message = "The scanned settings include a token. Would you like to set this as your access token?"
            }
        }

        // If both have URLs but they don't match, show warning
        if hasCurrentURL, hasScannedURL, currentURL != url {
            shouldPromptForURL = true
            message = "The scanned Nightscout URL (\(url)) doesn't match your current Nightscout address (\(currentURL)). Would you like to change your Nightscout address to match the scanned settings?"
        }

        // If both have tokens but they don't match, show warning
        if hasCurrentToken, hasScannedToken, currentToken != token {
            shouldPromptForToken = true
            if !message.isEmpty {
                message += "\n\nThe scanned token doesn't match your current access token. Would you like to update your token?"
            } else {
                message = "The scanned token doesn't match your current access token. Would you like to update your token?"
            }
        }

        let isCompatible = !shouldPromptForURL && !shouldPromptForToken

        return (isCompatible, shouldPromptForURL, shouldPromptForToken, message)
    }
}
