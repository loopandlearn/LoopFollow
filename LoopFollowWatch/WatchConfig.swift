// LoopFollow
// WatchConfig.swift

import Foundation

struct WatchConfig: Equatable {
    var nsURL: String
    var nsToken: String
    var dexUsername: String
    var dexPassword: String
    var dexServer: String // "US" or "NON_US"
    var units: String // "mg/dL" or "mmol/L"
    var lowLine: Double
    var highLine: Double

    // Remote control fields
    var remoteType: String // "None", "Nightscout", "Trio Remote Control", "Loop APNS"
    var maxBolus: Double
    var maxCarbs: Double

    // TRC APNS credentials
    var trcDeviceToken: String
    var trcSharedSecret: String
    var trcApnsKey: String
    var trcKeyId: String
    var trcTeamId: String
    var trcBundleId: String
    var trcProductionEnv: Bool
    var trcUser: String

    // Nightscout write auth
    var nsWriteAuth: Bool

    var hasDexcomCredentials: Bool {
        !dexUsername.isEmpty && !dexPassword.isEmpty
    }

    var hasNightscoutURL: Bool {
        !nsURL.isEmpty
    }

    var hasAnySource: Bool {
        hasDexcomCredentials || hasNightscoutURL
    }

    var remoteEnabled: Bool {
        remoteType != "None"
    }

    var dexServerURL: String {
        dexServer == "US"
            ? "https://share2.dexcom.com"
            : "https://shareous1.dexcom.com"
    }

    func toDictionary() -> [String: Any] {
        [
            "nsURL": nsURL,
            "nsToken": nsToken,
            "dexUsername": dexUsername,
            "dexPassword": dexPassword,
            "dexServer": dexServer,
            "units": units,
            "lowLine": lowLine,
            "highLine": highLine,
            "remoteType": remoteType,
            "maxBolus": maxBolus,
            "maxCarbs": maxCarbs,
            "trcDeviceToken": trcDeviceToken,
            "trcSharedSecret": trcSharedSecret,
            "trcApnsKey": trcApnsKey,
            "trcKeyId": trcKeyId,
            "trcTeamId": trcTeamId,
            "trcBundleId": trcBundleId,
            "trcProductionEnv": trcProductionEnv,
            "trcUser": trcUser,
            "nsWriteAuth": nsWriteAuth,
        ]
    }

    init(from dict: [String: Any]) {
        nsURL = dict["nsURL"] as? String ?? ""
        nsToken = dict["nsToken"] as? String ?? ""
        dexUsername = dict["dexUsername"] as? String ?? ""
        dexPassword = dict["dexPassword"] as? String ?? ""
        dexServer = dict["dexServer"] as? String ?? "US"
        units = dict["units"] as? String ?? "mg/dL"
        lowLine = dict["lowLine"] as? Double ?? 70.0
        highLine = dict["highLine"] as? Double ?? 180.0
        remoteType = dict["remoteType"] as? String ?? "None"
        maxBolus = dict["maxBolus"] as? Double ?? 10.0
        maxCarbs = dict["maxCarbs"] as? Double ?? 100.0
        trcDeviceToken = dict["trcDeviceToken"] as? String ?? ""
        trcSharedSecret = dict["trcSharedSecret"] as? String ?? ""
        trcApnsKey = dict["trcApnsKey"] as? String ?? ""
        trcKeyId = dict["trcKeyId"] as? String ?? ""
        trcTeamId = dict["trcTeamId"] as? String ?? ""
        trcBundleId = dict["trcBundleId"] as? String ?? ""
        trcProductionEnv = dict["trcProductionEnv"] as? Bool ?? false
        trcUser = dict["trcUser"] as? String ?? ""
        nsWriteAuth = dict["nsWriteAuth"] as? Bool ?? false
    }

    func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(toDictionary(), forKey: "watchConfig")
    }

    static func loadFromDefaults() -> WatchConfig? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "watchConfig") else {
            return nil
        }
        return WatchConfig(from: dict)
    }
}
