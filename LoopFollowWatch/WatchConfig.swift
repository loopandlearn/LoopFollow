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

    // LoopFollow's own APNS credentials — used to populate
    // `return_notification` so Trio's ack lands on the iPhone, which
    // can forward it to the watch over WCSession.
    var lfDeviceToken: String
    var lfApnsKey: String
    var lfKeyId: String
    var lfTeamId: String
    var lfBundleId: String
    var lfProductionEnv: Bool

    // Nightscout write auth
    var nsWriteAuth: Bool

    // Meal settings (synced from iPhone)
    var mealWithFatProtein: Bool
    var maxProtein: Double
    var maxFat: Double

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
            "lfDeviceToken": lfDeviceToken,
            "lfApnsKey": lfApnsKey,
            "lfKeyId": lfKeyId,
            "lfTeamId": lfTeamId,
            "lfBundleId": lfBundleId,
            "lfProductionEnv": lfProductionEnv,
            "nsWriteAuth": nsWriteAuth,
            "mealWithFatProtein": mealWithFatProtein,
            "maxProtein": maxProtein,
            "maxFat": maxFat,
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
        lfDeviceToken = dict["lfDeviceToken"] as? String ?? ""
        lfApnsKey = dict["lfApnsKey"] as? String ?? ""
        lfKeyId = dict["lfKeyId"] as? String ?? ""
        lfTeamId = dict["lfTeamId"] as? String ?? ""
        lfBundleId = dict["lfBundleId"] as? String ?? ""
        lfProductionEnv = dict["lfProductionEnv"] as? Bool ?? false
        nsWriteAuth = dict["nsWriteAuth"] as? Bool ?? false
        mealWithFatProtein = dict["mealWithFatProtein"] as? Bool ?? false
        maxProtein = dict["maxProtein"] as? Double ?? 30.0
        maxFat = dict["maxFat"] as? Double ?? 30.0
    }

    func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(toDictionary(), forKey: "watchConfig")

        // Also mirror NS credentials to the App Group so the widget extension
        // (a separate process) can fetch BG directly from Nightscout.
        if let shared = UserDefaults(suiteName: WidgetData.appGroupID) {
            shared.set(nsURL, forKey: "nsURL")
            shared.set(nsToken, forKey: "nsToken")
        }
    }

    static func loadFromDefaults() -> WatchConfig? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "watchConfig") else {
            return nil
        }
        return WatchConfig(from: dict)
    }
}
