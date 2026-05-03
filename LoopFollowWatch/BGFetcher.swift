// LoopFollow
// BGFetcher.swift

import Combine
import Foundation

class BGFetcher: ObservableObject {
    @Published var currentBG: BGReading?
    @Published var bgHistory: [BGReading] = []
    @Published var loopStatus: LoopStatus?
    @Published var overridePresets: [OverridePreset] = []
    @Published var scheduledBasal: Double?
    @Published var lastError: String?
    @Published var isReloading = false
    @Published var activeSource: String = "" // "Nightscout" or "Dexcom"

    private var timer: Timer?
    private var dexSessionToken: String?
    private var profileLoaded = false
    private var basalSchedule: [(timeAsSeconds: Double, value: Double)] = []
    private var profileTimezone: TimeZone = .current

    private let dexcomUserAgent = "Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0"
    private let dexcomApplicationId = "d89443d2-327c-4a6f-89e5-496bbb0317db"

    func start(config: WatchConfig) {
        stop()
        profileLoaded = false
        fetch(config: config)
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetch(config: config)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func reload() {
        // Called by double-tap on freshness text
        guard let config = currentConfig else { return }
        DispatchQueue.main.async { self.isReloading = true }
        fetch(config: config)
    }

    private var currentConfig: WatchConfig?

    func fetch(config: WatchConfig) {
        currentConfig = config

        // Always fetch from Nightscout if available (BG entries + devicestatus + profile)
        if config.hasNightscoutURL {
            fetchNightscout(config: config)
            fetchDeviceStatus(config: config)
            if !profileLoaded {
                fetchProfile(config: config)
            }
        }

        // Also try Dexcom if credentials are present and Nightscout is not available
        // (if both are available, Nightscout is preferred since it has devicestatus/profile too)
        if config.hasDexcomCredentials && !config.hasNightscoutURL {
            fetchDexcom(config: config)
        }
    }

    // MARK: - Nightscout BG Entries

    private func fetchNightscout(config: WatchConfig) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/entries.json"

        var queryItems = [URLQueryItem]()
        if !config.nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: config.nsToken))
        }
        queryItems.append(URLQueryItem(name: "count", value: "300"))
        queryItems.append(URLQueryItem(name: "find[type][$ne]", value: "cal"))
        components?.queryItems = queryItems

        guard let url = components?.url else {
            DispatchQueue.main.async { self.lastError = "Invalid Nightscout URL" }
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { self.lastError = "No data received" }
                return
            }

            self.parseNightscoutResponse(data: data)
        }.resume()
    }

    private func parseNightscoutResponse(data: Data) {
        struct NSEntry: Decodable {
            var sgv: Double?
            var mbg: Double?
            var glucose: Double?
            var date: TimeInterval
            var direction: String?

            var bgValue: Int? {
                if let sgv = sgv { return Int(sgv.rounded()) }
                if let mbg = mbg { return Int(mbg.rounded()) }
                if let glucose = glucose { return Int(glucose.rounded()) }
                return nil
            }
        }

        do {
            let entries = try JSONDecoder().decode([NSEntry].self, from: data)
            var readings: [BGReading] = []

            for (index, entry) in entries.enumerated() {
                guard let bgValue = entry.bgValue else { continue }
                let timestamp = Date(timeIntervalSince1970: entry.date / 1000)
                let direction = entry.direction ?? ""
                let delta: Int?
                if index + 1 < entries.count, let priorBG = entries[index + 1].bgValue {
                    delta = bgValue - priorBG
                } else {
                    delta = nil
                }
                readings.append(BGReading(
                    bgValue: bgValue,
                    direction: BGReading.directionArrow(direction),
                    timestamp: timestamp,
                    delta: delta
                ))
            }

            DispatchQueue.main.async {
                self.bgHistory = readings
                self.currentBG = readings.first
                self.isReloading = false
                if readings.isEmpty {
                    self.lastError = "No BG entries"
                } else {
                    self.lastError = nil
                    self.activeSource = "Nightscout"
                }
            }
        } catch {
            DispatchQueue.main.async { self.lastError = "Parse error" }
        }
    }

    private func fallbackToNightscout(config: WatchConfig, dexError: String) {
        if config.hasNightscoutURL {
            fetchNightscout(config: config)
        } else {
            DispatchQueue.main.async { self.lastError = dexError }
        }
    }

    // MARK: - Nightscout Device Status

    func fetchDeviceStatus(config: WatchConfig) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/devicestatus.json"

        var queryItems = [URLQueryItem]()
        if !config.nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: config.nsToken))
        }
        queryItems.append(URLQueryItem(name: "count", value: "1"))
        components?.queryItems = queryItems

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data else { return }
            self.parseDeviceStatus(data: data)
        }.resume()
    }

    func fetchDeviceStatusAt(config: WatchConfig, date: Date) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/devicestatus.json"

        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)

        var queryItems = [URLQueryItem]()
        if !config.nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: config.nsToken))
        }
        queryItems.append(URLQueryItem(name: "count", value: "1"))
        queryItems.append(URLQueryItem(name: "find[created_at][$lte]", value: dateString))
        components?.queryItems = queryItems

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data else { return }
            self.parseDeviceStatus(data: data)
        }.resume()
    }

    private func parseDeviceStatus(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let entries = json as? [[String: Any]],
              let lastEntry = entries.first
        else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        // Detect Loop vs OpenAPS
        if let loopRecord = lastEntry["loop"] as? [String: Any] {
            parseLoopDeviceStatus(entry: lastEntry, loopRecord: loopRecord, formatter: formatter)
        } else if let openapsRecord = lastEntry["openaps"] as? [String: Any] {
            parseOpenAPSDeviceStatus(entry: lastEntry, openapsRecord: openapsRecord, formatter: formatter)
        }
    }

    private func parseLoopDeviceStatus(entry: [String: Any], loopRecord: [String: Any], formatter: ISO8601DateFormatter) {
        var iob: Double?
        var cob: Double?
        var basalRate: Double?
        var overrideActive = false
        var overrideText: String?
        var predictions: [Double]?
        var predictionStart: Date?

        // Timestamp
        let timestamp: Date
        if let ts = loopRecord["timestamp"] as? String, let d = formatter.date(from: ts) {
            timestamp = d
        } else {
            timestamp = Date()
        }

        // IOB
        if let iobData = loopRecord["iob"] as? [String: Any],
           let iobValue = iobData["iob"] as? Double {
            iob = iobValue
        }

        // COB
        if let cobData = loopRecord["cob"] as? [String: Any],
           let cobValue = cobData["cob"] as? Double {
            cob = cobValue
        }

        // Basal
        if let enacted = loopRecord["enacted"] as? [String: Any],
           let rate = enacted["rate"] as? Double {
            basalRate = rate
        }

        // Predictions
        if let predictData = loopRecord["predicted"] as? [String: Any],
           let values = predictData["values"] as? [Double] {
            predictions = values
            predictionStart = timestamp
        }

        // Override (top-level in devicestatus for Loop)
        if let overrideData = entry["override"] as? [String: Any],
           let isActive = overrideData["active"] as? Bool, isActive {
            overrideActive = true
            var oText = ""
            if let multiplier = overrideData["multiplier"] as? Double {
                oText += String(format: "%.0f%%", multiplier * 100)
            } else {
                oText += "100%"
            }
            if let correction = overrideData["currentCorrectionRange"] as? [String: Any],
               let minVal = correction["minValue"] as? Double,
               let maxVal = correction["maxValue"] as? Double {
                oText += " (\(Int(minVal))-\(Int(maxVal)))"
            }
            overrideText = oText
        }

        let status = LoopStatus(
            iob: iob, cob: cob, basalRate: basalRate,
            overrideActive: overrideActive, overrideText: overrideText,
            timestamp: timestamp,
            predictions: predictions, predictionStart: predictionStart,
            ztPredictions: nil, iobPredictions: nil,
            cobPredictions: nil, uamPredictions: nil,
            isOpenAPS: false,
            tempTargetActive: false, tempTargetText: nil
        )

        DispatchQueue.main.async {
            self.loopStatus = status
            self.updateScheduledBasal(for: timestamp)
        }
    }

    private func parseOpenAPSDeviceStatus(entry: [String: Any], openapsRecord: [String: Any], formatter: ISO8601DateFormatter) {
        var iob: Double?
        var cob: Double?
        var basalRate: Double?
        var overrideActive = false
        var overrideText: String?
        var ztPredictions: [Double]?
        var iobPredictions: [Double]?
        var cobPredictions: [Double]?
        var uamPredictions: [Double]?
        var predictionStart: Date?

        let enactedOrSuggested = openapsRecord["suggested"] as? [String: Any]
            ?? openapsRecord["enacted"] as? [String: Any]

        // Timestamp
        let timestamp: Date
        if let ts = enactedOrSuggested?["timestamp"] as? String, let d = formatter.date(from: ts) {
            timestamp = d
            predictionStart = d
        } else {
            timestamp = Date()
            predictionStart = Date()
        }

        // IOB
        if let iobData = openapsRecord["iob"] as? [String: Any],
           let iobValue = iobData["iob"] as? Double {
            iob = iobValue
        }

        // COB - try direct field first, then regex from reason
        if let cobValue = enactedOrSuggested?["COB"] as? Double {
            cob = cobValue
        } else if let reason = enactedOrSuggested?["reason"] as? String {
            let pattern = "COB: (\\d+(?:\\.\\d+)?)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: reason, range: NSRange(location: 0, length: reason.utf16.count)) {
                let valueString = (reason as NSString).substring(with: match.range(at: 1))
                cob = Double(valueString)
            }
        }

        // Basal from enacted
        if let enacted = openapsRecord["enacted"] as? [String: Any],
           let rate = enacted["rate"] as? Double {
            basalRate = rate
        }

        // Predictions - all four types
        let predBGsData: [String: Any]? = {
            if let suggested = openapsRecord["suggested"] as? [String: Any],
               let predBGs = suggested["predBGs"] as? [String: Any] {
                return predBGs
            } else if let enacted = openapsRecord["enacted"] as? [String: Any],
                      let predBGs = enacted["predBGs"] as? [String: Any] {
                return predBGs
            }
            return nil
        }()

        if let predBGs = predBGsData {
            ztPredictions = predBGs["ZT"] as? [Double]
            iobPredictions = predBGs["IOB"] as? [Double]
            cobPredictions = predBGs["COB"] as? [Double]
            uamPredictions = predBGs["UAM"] as? [Double]
        }

        // Temp target — only detect from explicit "targetBottom"/"targetTop" in enacted,
        // not from the reason string (which always includes "Target:" for the profile target)
        var tempTargetActive = false
        var tempTargetText: String?
        if let enacted = openapsRecord["enacted"] as? [String: Any],
           let targetBG = enacted["target_bg"] as? Double,
           let currentTarget = enactedOrSuggested?["current_target"] as? Double,
           targetBG != currentTarget {
            tempTargetActive = true
            tempTargetText = "\(Int(targetBG)) mg/dL"
        }

        let status = LoopStatus(
            iob: iob, cob: cob, basalRate: basalRate,
            overrideActive: overrideActive, overrideText: overrideText,
            timestamp: timestamp,
            predictions: nil, predictionStart: predictionStart,
            ztPredictions: ztPredictions, iobPredictions: iobPredictions,
            cobPredictions: cobPredictions, uamPredictions: uamPredictions,
            isOpenAPS: true,
            tempTargetActive: tempTargetActive, tempTargetText: tempTargetText
        )

        DispatchQueue.main.async {
            self.loopStatus = status
            self.updateScheduledBasal(for: timestamp)
        }
    }

    // MARK: - Nightscout Profile (Override Presets)

    private func updateScheduledBasal(for date: Date) {
        guard !basalSchedule.isEmpty else { return }
        var calendar = Calendar.current
        calendar.timeZone = profileTimezone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentSeconds = Double(components.hour ?? 0) * 3600 + Double(components.minute ?? 0) * 60 + Double(components.second ?? 0)

        var scheduled: Double?
        for entry in basalSchedule {
            if currentSeconds >= entry.timeAsSeconds {
                scheduled = entry.value
            }
        }
        // If before first entry, use last entry (wraps around midnight)
        if scheduled == nil, let last = basalSchedule.last {
            scheduled = last.value
        }

        DispatchQueue.main.async { self.scheduledBasal = scheduled }
    }

    private func fetchProfile(config: WatchConfig) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/profile/current.json"

        var queryItems = [URLQueryItem]()
        if !config.nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: config.nsToken))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data else { return }
            self.parseProfile(data: data)
        }.resume()
    }

    private func parseProfile(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else { return }

        // Profile can be a single object or an array
        let profileDict: [String: Any]?
        if let array = json as? [[String: Any]] {
            profileDict = array.first
        } else if let dict = json as? [String: Any] {
            profileDict = dict
        } else {
            return
        }

        guard let profile = profileDict else { return }

        var presets: [OverridePreset] = []

        // Find the default store
        let defaultProfileName = profile["defaultProfile"] as? String ?? "default"
        let store = profile["store"] as? [String: Any]
        let defaultStore = store?[defaultProfileName] as? [String: Any]
            ?? store?["Default"] as? [String: Any]
            ?? store?.values.first as? [String: Any]

        // Extract basal schedule from default store
        if let basalArray = defaultStore?["basal"] as? [[String: Any]] {
            var schedule: [(timeAsSeconds: Double, value: Double)] = []
            for entry in basalArray {
                guard let value = entry["value"] as? Double else { continue }
                let timeAsSeconds = entry["timeAsSeconds"] as? Double ?? 0
                schedule.append((timeAsSeconds: timeAsSeconds, value: value))
            }
            schedule.sort { $0.timeAsSeconds < $1.timeAsSeconds }
            basalSchedule = schedule
        }

        // Extract timezone
        if let tz = defaultStore?["timezone"] as? String,
           let timezone = TimeZone(identifier: tz) {
            profileTimezone = timezone
        }

        // Trio overrides — JSON key is "overridePresets" at profile top level
        // (NSProfile.swift maps this via CodingKeys: case trioOverrides = "overridePresets")
        if let trioOverrides = profile["overridePresets"] as? [[String: Any]] {
            for override in trioOverrides {
                guard let name = override["name"] as? String else { continue }
                let duration = override["duration"] as? Double
                let percentage = override["percentage"] as? Double
                let target = override["target"] as? Double
                presets.append(OverridePreset(name: name, duration: duration, percentage: percentage, target: target))
            }
        }

        // Also check inside the default store for overridePresets
        if presets.isEmpty, let storeOverrides = defaultStore?["overridePresets"] as? [[String: Any]] {
            for override in storeOverrides {
                guard let name = override["name"] as? String else { continue }
                let duration = override["duration"] as? Double
                let percentage = override["percentage"] as? Double
                let target = override["target"] as? Double
                presets.append(OverridePreset(name: name, duration: duration, percentage: percentage, target: target))
            }
        }

        // Loop overrides from loopSettings
        if let loopSettings = profile["loopSettings"] as? [String: Any],
           let overridePresetsArray = loopSettings["overridePresets"] as? [[String: Any]] {
            for preset in overridePresetsArray {
                guard let name = preset["name"] as? String else { continue }
                let duration = preset["duration"] as? Double
                let scaleFactor = preset["insulinNeedsScaleFactor"] as? Double
                let percentage = scaleFactor.map { $0 * 100 }
                presets.append(OverridePreset(name: name, duration: duration, percentage: percentage, target: nil))
            }
        }

        // Also check loopSettings inside default store
        if presets.isEmpty,
           let storeLoopSettings = defaultStore?["loopSettings"] as? [String: Any],
           let overridePresetsArray = storeLoopSettings["overridePresets"] as? [[String: Any]] {
            for preset in overridePresetsArray {
                guard let name = preset["name"] as? String else { continue }
                let duration = preset["duration"] as? Double
                let scaleFactor = preset["insulinNeedsScaleFactor"] as? Double
                let percentage = scaleFactor.map { $0 * 100 }
                presets.append(OverridePreset(name: name, duration: duration, percentage: percentage, target: nil))
            }
        }

        profileLoaded = true
        DispatchQueue.main.async {
            self.overridePresets = presets
            // Update scheduled basal for current time
            self.updateScheduledBasal(for: Date())
        }
    }

    // MARK: - Dexcom Share

    private func fetchDexcom(config: WatchConfig, retryCount: Int = 0) {
        if let token = dexSessionToken {
            fetchDexcomGlucose(config: config, sessionToken: token, retryCount: retryCount)
        } else {
            authenticateDexcom(config: config, retryCount: retryCount)
        }
    }

    private func authenticateDexcom(config: WatchConfig, retryCount: Int) {
        let url = URL(string: config.dexServerURL + "/ShareWebServices/Services/General/AuthenticatePublisherAccount")!
        let body: [String: Any] = [
            "accountName": config.dexUsername,
            "password": config.dexPassword,
            "applicationId": dexcomApplicationId,
        ]

        dexcomPOST(url: url, body: body) { [weak self] error, response in
            guard let self = self else { return }
            if let error = error {
                self.fallbackToNightscout(config: config, dexError: "Dexcom auth failed: \(error.localizedDescription)")
                return
            }

            guard let response = response,
                  let data = response.data(using: .utf8),
                  let accountId = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? String
            else {
                self.fallbackToNightscout(config: config, dexError: "Dexcom auth: invalid response")
                return
            }

            self.loginDexcom(config: config, accountId: accountId, retryCount: retryCount)
        }
    }

    private func loginDexcom(config: WatchConfig, accountId: String, retryCount: Int) {
        let url = URL(string: config.dexServerURL + "/ShareWebServices/Services/General/LoginPublisherAccountById")!
        let body: [String: Any] = [
            "accountId": accountId,
            "password": config.dexPassword,
            "applicationId": dexcomApplicationId,
        ]

        dexcomPOST(url: url, body: body) { [weak self] error, response in
            guard let self = self else { return }
            if let error = error {
                self.fallbackToNightscout(config: config, dexError: "Dexcom login failed: \(error.localizedDescription)")
                return
            }

            guard let response = response,
                  let data = response.data(using: .utf8),
                  let token = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? String
            else {
                self.fallbackToNightscout(config: config, dexError: "Dexcom login: invalid response")
                return
            }

            self.dexSessionToken = token
            self.fetchDexcomGlucose(config: config, sessionToken: token, retryCount: retryCount)
        }
    }

    private func fetchDexcomGlucose(config: WatchConfig, sessionToken: String, retryCount: Int) {
        var components = URLComponents(string: config.dexServerURL + "/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues")!
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionToken),
            URLQueryItem(name: "minutes", value: "1500"),
            URLQueryItem(name: "maxCount", value: "300"),
        ]

        dexcomPOST(url: components.url!, body: nil) { [weak self] error, response in
            guard let self = self else { return }
            if let error = error {
                self.fallbackToNightscout(config: config, dexError: "Dexcom fetch failed: \(error.localizedDescription)")
                return
            }

            guard let response = response,
                  let data = response.data(using: .utf8),
                  let decoded = try? JSONSerialization.jsonObject(with: data, options: []),
                  let sgvs = decoded as? [[String: Any]]
            else {
                if retryCount < 2 {
                    self.dexSessionToken = nil
                    self.fetchDexcom(config: config, retryCount: retryCount + 1)
                } else {
                    self.fallbackToNightscout(config: config, dexError: "Dexcom: failed after retries")
                }
                return
            }

            self.parseDexcomResponse(config: config, sgvs: sgvs)
        }
    }

    private func parseDexcomResponse(config: WatchConfig, sgvs: [[String: Any]]) {
        let trendMap = [
            "": 0, "DoubleUp": 1, "SingleUp": 2, "FortyFiveUp": 3,
            "Flat": 4, "FortyFiveDown": 5, "SingleDown": 6, "DoubleDown": 7,
            "NotComputable": 8, "RateOutOfRange": 9,
        ]

        let trendTable = [
            "NONE", "DoubleUp", "SingleUp", "FortyFiveUp", "Flat",
            "FortyFiveDown", "SingleDown", "DoubleDown", "NOT COMPUTABLE", "RATE OUT OF RANGE",
        ]

        var readings: [BGReading] = []

        for (index, sgv) in sgvs.enumerated() {
            guard let glucose = sgv["Value"] as? Int,
                  let wt = sgv["WT"] as? String
            else { continue }

            let trendIndex: Int
            if let trendString = sgv["Trend"] as? String {
                trendIndex = trendMap[trendString] ?? 0
            } else if let trendInt = sgv["Trend"] as? Int {
                trendIndex = trendInt
            } else {
                trendIndex = 0
            }

            let direction = trendIndex < trendTable.count ? trendTable[trendIndex] : "NONE"
            guard let timestamp = parseDexcomDate(wt) else { continue }

            let delta: Int?
            if index + 1 < sgvs.count, let nextGlucose = sgvs[index + 1]["Value"] as? Int {
                delta = glucose - nextGlucose
            } else {
                delta = nil
            }

            readings.append(BGReading(
                bgValue: glucose,
                direction: BGReading.directionArrow(direction),
                timestamp: timestamp,
                delta: delta
            ))
        }

        guard !readings.isEmpty else {
            self.fallbackToNightscout(config: config, dexError: "No Dexcom readings")
            return
        }

        DispatchQueue.main.async {
            self.bgHistory = readings
            self.currentBG = readings.first
            self.isReloading = false
            self.lastError = nil
            self.activeSource = "Dexcom"
        }
    }

    private func parseDexcomDate(_ wt: String) -> Date? {
        guard let range = wt.range(of: "\\((.*)\\)", options: .regularExpression),
              let epoch = Double(wt[range].dropFirst().dropLast())
        else { return nil }
        return Date(timeIntervalSince1970: epoch / 1000)
    }

    private func dexcomPOST(url: URL, body: [String: Any]?, completion: @escaping (Error?, String?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(dexcomUserAgent, forHTTPHeaderField: "User-Agent")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(error, nil)
            } else if let data = data {
                completion(nil, String(data: data, encoding: .utf8))
            } else {
                completion(nil, nil)
            }
        }.resume()
    }
}
