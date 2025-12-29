// LoopFollow
// ExportableSettings.swift

import Foundation
import HealthKit

// MARK: - Nightscout Settings Export

struct NightscoutSettingsExport: Codable {
    let version: String
    let url: String
    let token: String
    let units: String

    static func fromCurrentStorage() -> NightscoutSettingsExport {
        let storage = Storage.shared
        return NightscoutSettingsExport(
            version: AppVersionManager().version(),
            url: storage.url.value,
            token: storage.token.value,
            units: storage.units.value
        )
    }

    func applyToStorage() {
        let storage = Storage.shared
        storage.url.value = url
        storage.token.value = token
        storage.units.value = units
    }

    func encodeToJSON() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func hasValidSettings() -> Bool {
        return !url.isEmpty && !token.isEmpty
    }
}

// MARK: - Dexcom Settings Export

struct DexcomSettingsExport: Codable {
    let version: String
    let userName: String
    let password: String
    let server: String

    static func fromCurrentStorage() -> DexcomSettingsExport {
        let storage = Storage.shared
        return DexcomSettingsExport(
            version: AppVersionManager().version(),
            userName: storage.shareUserName.value,
            password: storage.sharePassword.value,
            server: storage.shareServer.value
        )
    }

    func applyToStorage() {
        let storage = Storage.shared
        storage.shareUserName.value = userName
        storage.sharePassword.value = password
        storage.shareServer.value = server
    }

    func encodeToJSON() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func hasValidSettings() -> Bool {
        return !userName.isEmpty && !password.isEmpty
    }
}

// MARK: - Alarm Settings Export

struct AlarmSettingsExport: Codable {
    let version: String
    let alarms: [Alarm]
    let alarmConfiguration: AlarmConfiguration

    static func fromCurrentStorage() -> AlarmSettingsExport {
        let storage = Storage.shared
        return AlarmSettingsExport(
            version: AppVersionManager().version(),
            alarms: storage.alarms.value,
            alarmConfiguration: storage.alarmConfiguration.value
        )
    }

    static func fromSelectedAlarms(_ selectedAlarms: [Alarm]) -> AlarmSettingsExport {
        let storage = Storage.shared
        return AlarmSettingsExport(
            version: AppVersionManager().version(),
            alarms: selectedAlarms,
            alarmConfiguration: storage.alarmConfiguration.value
        )
    }

    func applyToStorage() {
        let storage = Storage.shared
        // When importing, merge with existing alarms instead of replacing
        var existingAlarms = storage.alarms.value
        var updatedAlarms: [Alarm] = []

        // Keep existing alarms that aren't being imported
        for existingAlarm in existingAlarms {
            if !alarms.contains(where: { $0.id == existingAlarm.id }) {
                updatedAlarms.append(existingAlarm)
            }
        }

        // Add imported alarms
        updatedAlarms.append(contentsOf: alarms)

        storage.alarms.value = updatedAlarms
        storage.alarmConfiguration.value = alarmConfiguration
    }

    func encodeToJSON() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func hasValidSettings() -> Bool {
        return !alarms.isEmpty
    }
}

// MARK: - Remote Settings Export

struct RemoteSettingsExport: Codable {
    let version: String
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
    let device: String

    static func fromCurrentStorage() -> RemoteSettingsExport {
        let storage = Storage.shared
        return RemoteSettingsExport(
            version: AppVersionManager().version(),
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
            device: storage.device.value
        )
    }

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

        // Set device temporarily from import (will be overridden by Nightscout connection)
        if !device.isEmpty {
            storage.device.value = device
        } else {
            // Fallback to automatic device type based on remote type
            switch remoteType {
            case .loopAPNS:
                storage.device.value = "Loop"
            case .trc:
                storage.device.value = "Trio"
            case .nightscout:
                // For Nightscout, we don't automatically set device type
                // as it should be determined by the actual connection
                break
            case .none:
                break
            }
        }
    }

    func encodeToJSON() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func hasValidSettings() -> Bool {
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

    /// Validates compatibility with current storage settings
    func validateCompatibilityWithCurrentStorage() -> (isCompatible: Bool, shouldPromptForURL: Bool, shouldPromptForToken: Bool, message: String) {
        let storage = Storage.shared
        var message = ""
        var shouldPromptForURL = false
        var shouldPromptForToken = false

        // Check if there are existing remote settings
        let currentRemoteType = storage.remoteType.value
        let currentUser = storage.user.value

        // If remote type is changing, warn user
        if currentRemoteType != .none && currentRemoteType != remoteType {
            message += "Remote type is changing from \(currentRemoteType.rawValue) to \(remoteType.rawValue). This may affect your remote commands.\n"
        }

        // If user is changing, warn user
        if !currentUser.isEmpty && currentUser != user {
            message += "Remote user is changing from '\(currentUser)' to '\(user)'. This may affect your remote commands.\n"
        }

        // For TRC and LoopAPNS, check if key details are changing
        if remoteType == .trc || remoteType == .loopAPNS {
            let currentKeyId = storage.keyId.value
            let currentApnsKey = storage.apnsKey.value

            if !currentKeyId.isEmpty, currentKeyId != keyId {
                message += "APNS Key ID is changing. This may affect your remote commands.\n"
            }

            if !currentApnsKey.isEmpty, currentApnsKey != apnsKey {
                message += "APNS Key is changing. This may affect your remote commands.\n"
            }
        }

        // For TRC, check shared secret
        if remoteType == .trc {
            let currentSharedSecret = storage.sharedSecret.value
            if !currentSharedSecret.isEmpty, currentSharedSecret != sharedSecret {
                message += "Shared secret is changing. This may affect your remote commands.\n"
            }
        }

        // For LoopAPNS, check team ID and QR code URL
        if remoteType == .loopAPNS {
            let currentTeamId = storage.teamId.value
            let currentQrCodeURL = storage.loopAPNSQrCodeURL.value

            if let teamId = teamId, let currentTeamId = currentTeamId, teamId != currentTeamId {
                message += "Team ID is changing. This may affect your remote commands.\n"
            }

            if !currentQrCodeURL.isEmpty, currentQrCodeURL != loopAPNSQrCodeURL {
                message += "Loop APNS QR Code URL is changing. This may affect your remote commands.\n"
            }
        }

        // If both have tokens but they don't match, show warning
        let hasCurrentToken = !storage.token.value.isEmpty
        if hasCurrentToken {
            message += "Note: This import does not include Nightscout token settings. Your current Nightscout token will be preserved.\n"
        }

        let isCompatible = !shouldPromptForURL && !shouldPromptForToken

        return (isCompatible, shouldPromptForURL, shouldPromptForToken, message)
    }
}

// MARK: - Combined Settings Export

struct CombinedSettingsExport: Codable {
    let version: String
    let appVersion: String
    let nightscout: NightscoutSettingsExport?
    let dexcom: DexcomSettingsExport?
    let remote: RemoteSettingsExport?
    let alarms: AlarmSettingsExport?
    let exportType: String
    let timestamp: Date

    init(nightscout: NightscoutSettingsExport? = nil,
         dexcom: DexcomSettingsExport? = nil,
         remote: RemoteSettingsExport? = nil,
         alarms: AlarmSettingsExport? = nil,
         exportType: String)
    {
        version = "1.0"
        appVersion = AppVersionManager().version()
        self.nightscout = nightscout
        self.dexcom = dexcom
        self.remote = remote
        self.alarms = alarms
        self.exportType = exportType
        timestamp = Date()
    }

    func encodeToJSON() -> String? {
        do {
            let data = try JSONEncoder().encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func decodeFromJSON(_ jsonString: String) -> CombinedSettingsExport? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(CombinedSettingsExport.self, from: data)
        } catch {
            return nil
        }
    }
}
