// LoopFollow
// BGFetcher.swift

import Combine
import Foundation
import WidgetKit

// MARK: - Widget Data (shared with LoopFollowWidgets target via UserDefaults)

struct WidgetBGPoint: Codable, Hashable {
    let value: Int // mg/dL
    let timestamp: Date
}

struct WidgetData: Codable {
    let bgValue: Int
    let direction: String
    let delta: Int?
    let bgTimestamp: Date
    let iob: Double?
    let cob: Double?
    let basalRate: Double?
    let scheduledBasal: Double?
    let history: [WidgetBGPoint]
    let units: String
    let updatedAt: Date

    private static let storageKey = "widgetData"

    /// App Group shared between the watch app and widget extension.
    static let appGroupID = "group.loopfollow.shared"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.sharedDefaults.set(data, forKey: Self.storageKey)
    }

    static func load() -> WidgetData? {
        guard let data = sharedDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return decoded
    }
}

// MARK: - Bolus Calculation

struct BolusCalculation {
    let bg: Double
    let target: Double
    let isf: Double
    let iob: Double
    let cob: Double
    let pendingCarbs: Double
    let cr: Double
    let delta: Double
    let glucoseEffect: Double
    let iobEffect: Double
    let cobEffect: Double
    let deltaEffect: Double
    let fullBolus: Double
}

class BGFetcher: ObservableObject {
    /// Process-wide singleton. Used by both the SwiftUI App body (@StateObject)
    /// and the `ExtensionDelegate` background-task handler. Making this a
    /// singleton fixes the bug where a cold background launch left the
    /// delegate's weak reference nil — the delegate can now reach the fetcher
    /// directly without depending on `.onAppear` firing first.
    static let shared = BGFetcher()

    @Published var currentBG: BGReading?
    @Published var bgHistory: [BGReading] = []
    @Published var loopStatus: LoopStatus?
    @Published var overridePresets: [OverridePreset] = []
    @Published var scheduledBasal: Double?
    @Published var lastError: String?
    @Published var isReloading = false
    @Published var activeSource: String = "" // "Nightscout" or "Dexcom"
    @Published var statusMatchesScroll: Bool = true
    @Published var recommendedBolus: Double = 0
    @Published var bolusCalc: BolusCalculation?

    /// Carbs entered locally on the watch (e.g. from meal screen) not yet in remote COB.
    /// Set before navigating to the bolus screen; included in recommended bolus calculation.
    var pendingCarbs: Double = 0

    /// Insulin sent from the watch not yet reflected in remote IOB.
    /// Subtracted from the recommended bolus so the user doesn't
    /// double-dose while waiting for the next loop cycle.
    var pendingInsulin: Double = 0

    // Treatment data for chart display
    @Published var treatments: [Treatment] = []
    @Published var tempTargetEntries: [TempTargetEntry] = []
    @Published var overrideEntries: [OverrideEntry] = []

    // Profile + device-status detail surfaced in the Follow Status sheet.
    @Published private(set) var basalSchedule: [(timeAsSeconds: Double, value: Double)] = []
    @Published private(set) var isfSchedule: [(timeAsSeconds: Double, value: Double)] = []
    @Published private(set) var carbRatioSchedule: [(timeAsSeconds: Double, value: Double)] = []
    @Published private(set) var targetSchedule: [(timeAsSeconds: Double, value: Double)] = []
    @Published private(set) var profileTimezone: TimeZone = .current
    @Published private(set) var profileName: String?
    @Published private(set) var profileDIA: Double?
    @Published private(set) var uploaderBattery: Int?
    @Published private(set) var pumpBattery: Int?
    @Published private(set) var pumpReservoir: Double?
    /// Most-recent active temp basal's `absolute` value from the treatments
    /// stream. Mirrors what the iPhone Follow app displays — this is the
    /// pump-rounded delivered rate, which can differ from `loopStatus.basalRate`
    /// (which comes from `devicestatus.enacted.rate`, the algorithm's request).
    @Published private(set) var currentTempBasal: Double?
    @Published private(set) var cannulaChangeDate: Date?
    @Published private(set) var sensorChangeDate: Date?
    @Published private(set) var insulinChangeDate: Date?
    @Published private(set) var carbsToday: Double?

    private var timer: Timer?
    private var dexSessionToken: String?
    private var profileLoaded = false

    private let dexcomUserAgent = "Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0"
    private let dexcomApplicationId = "d89443d2-327c-4a6f-89e5-496bbb0317db"

    // MARK: - Adaptive fetch cadence

    //
    // CGM readings arrive every ~5 min. Rather than fetching on a fixed 5-min
    // repeating timer (which ends up phase-locked to whenever start() was
    // called, and so perpetually fetches just before each new reading lands),
    // we compute the next fetch time from the last successful reading's
    // timestamp:
    //
    //     nextFetch = bg.timestamp + readingInterval + uploadBuffer
    //
    // uploadBuffer is a small cushion for sensor → phone → Nightscout upload
    // latency. If the target is in the past (we're behind, or the next reading
    // is late), we clamp to lateReadingPollFloor so we poll at a reasonable
    // cadence without tight-looping. The ceiling caps how long we'll wait when
    // a sensor reading is genuinely missing.
    private static let readingInterval: TimeInterval = 300
    private static let uploadBuffer: TimeInterval = 10
    private static let lateReadingPollFloor: TimeInterval = 30
    private static let readingGapCeiling: TimeInterval = 330

    /// Compute the delay (seconds from now) until the next fetch, given the
    /// timestamp of the most recently known BG reading. Nil bgTimestamp means
    /// "no reading yet" — fall back to the ceiling so we retry periodically.
    static func nextFetchDelay(afterReadingAt bgTimestamp: Date?, now: Date = Date()) -> TimeInterval {
        guard let ts = bgTimestamp else { return readingGapCeiling }
        let target = ts.addingTimeInterval(readingInterval + uploadBuffer)
        let rawDelay = target.timeIntervalSince(now)
        return min(max(rawDelay, lateReadingPollFloor), readingGapCeiling)
    }

    func start(config: WatchConfig) {
        stop()
        profileLoaded = false
        fetch(config: config)
        // Initial one-shot timer. Rearmed by updateWidgetData() after each
        // successful fetch, based on the new reading's timestamp.
        scheduleNextFetch(config: config, delay: Self.readingGapCeiling)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Arm a one-shot timer to fire `delay` seconds from now. Replaces any
    /// existing scheduled fetch. Safe to call from main only.
    private func scheduleNextFetch(config: WatchConfig, delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.fetch(config: config)
        }
    }

    /// Re-arm the foreground timer based on the latest reading's timestamp,
    /// so the next fetch is scheduled right after the next reading is expected
    /// to be available on Nightscout.
    private func rearmForegroundTimer(after bgTimestamp: Date) {
        guard let config = currentConfig else { return }
        let delay = Self.nextFetchDelay(afterReadingAt: bgTimestamp)
        scheduleNextFetch(config: config, delay: delay)
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

        // Always fetch from Nightscout if available (BG entries + devicestatus + profile + treatments)
        if config.hasNightscoutURL {
            fetchNightscout(config: config)
            fetchDeviceStatus(config: config)
            fetchTreatments(config: config)
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
                    self.updateWidgetData()
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

    func fetchDeviceStatus(config: WatchConfig, completion: (() -> Void)? = nil) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/devicestatus.json"

        var queryItems = [URLQueryItem]()
        if !config.nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: config.nsToken))
        }
        queryItems.append(URLQueryItem(name: "count", value: "1"))
        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion?()
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            if let self = self, error == nil, let data = data {
                self.parseDeviceStatus(data: data)
            }
            DispatchQueue.main.async { completion?() }
        }.resume()
    }

    func fetchDeviceStatusAt(config: WatchConfig, date: Date) {
        DispatchQueue.main.async { self.statusMatchesScroll = false }
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
        else {
            DispatchQueue.main.async { self.statusMatchesScroll = true }
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        // Detect Loop vs OpenAPS
        if let loopRecord = lastEntry["loop"] as? [String: Any] {
            parseLoopDeviceStatus(entry: lastEntry, loopRecord: loopRecord, formatter: formatter)
        } else if let openapsRecord = lastEntry["openaps"] as? [String: Any] {
            parseOpenAPSDeviceStatus(entry: lastEntry, openapsRecord: openapsRecord, formatter: formatter)
        }
    }

    /// Pump battery percent. Handles the common shapes:
    /// `pump.battery.percent`, `pump.battery` as a number, or
    /// `pump.battery.voltage` (skipped — we only surface percent).
    private static func parsePumpBattery(entry: [String: Any]) -> Int? {
        guard let pump = entry["pump"] as? [String: Any] else { return nil }
        if let bDict = pump["battery"] as? [String: Any] {
            if let pct = bDict["percent"] as? Double { return Int(pct) }
            if let pct = bDict["percent"] as? Int { return pct }
            return nil
        }
        if let pct = pump["battery"] as? Double { return Int(pct) }
        if let pct = pump["battery"] as? Int { return pct }
        return nil
    }

    private func parseLoopDeviceStatus(entry: [String: Any], loopRecord: [String: Any], formatter: ISO8601DateFormatter) {
        var iob: Double?
        var cob: Double?
        var basalRate: Double?
        var overrideActive = false
        var overrideText: String?
        var predictions: [Double]?
        var predictionStart: Date?
        var recommendedBolus: Double?

        // Pump / uploader info live as siblings of `loop` on the devicestatus entry.
        let battery: Int? = {
            if let uploader = entry["uploader"] as? [String: Any],
               let b = uploader["battery"] as? Double
            {
                return Int(b)
            }
            return nil
        }()
        let pumpBatt = Self.parsePumpBattery(entry: entry)
        let reservoir = (entry["pump"] as? [String: Any])?["reservoir"] as? Double
        DispatchQueue.main.async {
            self.uploaderBattery = battery
            self.pumpBattery = pumpBatt
            self.pumpReservoir = reservoir
        }

        // Timestamp
        let timestamp: Date
        if let ts = loopRecord["timestamp"] as? String, let d = formatter.date(from: ts) {
            timestamp = d
        } else {
            timestamp = Date()
        }

        // IOB
        if let iobData = loopRecord["iob"] as? [String: Any],
           let iobValue = iobData["iob"] as? Double
        {
            iob = iobValue
        }

        // COB
        if let cobData = loopRecord["cob"] as? [String: Any],
           let cobValue = cobData["cob"] as? Double
        {
            cob = cobValue
        }

        // Basal
        if let enacted = loopRecord["enacted"] as? [String: Any],
           let rate = enacted["rate"] as? Double
        {
            basalRate = rate
        }

        // Predictions
        if let predictData = loopRecord["predicted"] as? [String: Any],
           let values = predictData["values"] as? [Double]
        {
            predictions = values
            predictionStart = timestamp
        }

        // Recommended Bolus
        if let recBolus = loopRecord["recommendedBolus"] as? Double {
            recommendedBolus = recBolus
        }

        // Override (top-level in devicestatus for Loop)
        if let overrideData = entry["override"] as? [String: Any],
           let isActive = overrideData["active"] as? Bool, isActive
        {
            overrideActive = true
            var oText = ""
            if let multiplier = overrideData["multiplier"] as? Double {
                oText += String(format: "%.0f%%", multiplier * 100)
            } else {
                oText += "100%"
            }
            if let correction = overrideData["currentCorrectionRange"] as? [String: Any],
               let minVal = correction["minValue"] as? Double,
               let maxVal = correction["maxValue"] as? Double
            {
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
            tempTargetActive: false, tempTargetText: nil,
            recommendedBolus: recommendedBolus, isf: nil, carbRatio: nil, currentTarget: nil,
            autosensRatio: nil, eventualBG: nil, tdd: nil,
            minPredBG: predictions?.min(), maxPredBG: predictions?.max(),
            insulinReq: nil, reason: nil
        )

        DispatchQueue.main.async {
            self.loopStatus = status
            self.pendingInsulin = 0
            self.statusMatchesScroll = true
            self.updateScheduledBasal(for: timestamp)
            self.updateRecommendedBolus()
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
        var isf: Double?
        var carbRatio: Double?
        var currentTarget: Double?

        // Pump / uploader info live as siblings of `openaps` on the devicestatus entry.
        let battery: Int? = {
            if let uploader = entry["uploader"] as? [String: Any],
               let b = uploader["battery"] as? Double
            {
                return Int(b)
            }
            return nil
        }()
        let pumpBatt = Self.parsePumpBattery(entry: entry)
        let reservoir = (entry["pump"] as? [String: Any])?["reservoir"] as? Double
        DispatchQueue.main.async {
            self.uploaderBattery = battery
            self.pumpBattery = pumpBatt
            self.pumpReservoir = reservoir
        }

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
           let iobValue = iobData["iob"] as? Double
        {
            iob = iobValue
        }

        // COB - try direct field first, then regex from reason
        if let cobValue = enactedOrSuggested?["COB"] as? Double {
            cob = cobValue
        } else if let reason = enactedOrSuggested?["reason"] as? String {
            let pattern = "COB: (\\d+(?:\\.\\d+)?)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: reason, range: NSRange(location: 0, length: reason.utf16.count))
            {
                let valueString = (reason as NSString).substring(with: match.range(at: 1))
                cob = Double(valueString)
            }
        }

        // ISF, CR, Target (autosens-adjusted from enacted/suggested)
        isf = enactedOrSuggested?["ISF"] as? Double
        currentTarget = enactedOrSuggested?["current_target"] as? Double
        if let reason = enactedOrSuggested?["reason"] as? String {
            let crPattern = "CR: (\\d+(?:\\.\\d+)?)"
            if let regex = try? NSRegularExpression(pattern: crPattern),
               let match = regex.firstMatch(in: reason, range: NSRange(location: 0, length: reason.utf16.count))
            {
                let valueString = (reason as NSString).substring(with: match.range(at: 1))
                carbRatio = Double(valueString)
            }
        }

        // Basal from enacted
        if let enacted = openapsRecord["enacted"] as? [String: Any],
           let rate = enacted["rate"] as? Double
        {
            basalRate = rate
        }

        // Predictions - all four types
        let predBGsData: [String: Any]? = {
            if let suggested = openapsRecord["suggested"] as? [String: Any],
               let predBGs = suggested["predBGs"] as? [String: Any]
            {
                return predBGs
            } else if let enacted = openapsRecord["enacted"] as? [String: Any],
                      let predBGs = enacted["predBGs"] as? [String: Any]
            {
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

        // Aggregate min/max across all predicted-BG arrays for the Follow Status sheet.
        let allPreds = (ztPredictions ?? []) + (iobPredictions ?? []) + (cobPredictions ?? []) + (uamPredictions ?? [])
        let minPredBG = allPreds.min()
        let maxPredBG = allPreds.max()

        // Extra OpenAPS/Trio fields surfaced in the Follow Status sheet.
        let autosensRatio = enactedOrSuggested?["sensitivityRatio"] as? Double
        let eventualBG = enactedOrSuggested?["eventualBG"] as? Double
        let insulinReq = enactedOrSuggested?["insulinReq"] as? Double
        let reasonText = enactedOrSuggested?["reason"] as? String

        // TDD: prefer the explicit field, otherwise regex it out of the reason string
        // (matches the iPhone fallback in DeviceStatusOpenAPS.swift).
        var tdd: Double? = enactedOrSuggested?["TDD"] as? Double
        if tdd == nil, let reason = reasonText {
            let pattern = "TDD:\\s*(\\d+(?:\\.\\d+)?)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: reason, range: NSRange(location: 0, length: reason.utf16.count))
            {
                let valueString = (reason as NSString).substring(with: match.range(at: 1))
                tdd = Double(valueString)
            }
        }

        // Temp target — only detect from explicit "targetBottom"/"targetTop" in enacted,
        // not from the reason string (which always includes "Target:" for the profile target)
        var tempTargetActive = false
        var tempTargetText: String?
        if let enacted = openapsRecord["enacted"] as? [String: Any],
           let targetBG = enacted["target_bg"] as? Double,
           let currentTarget = enactedOrSuggested?["current_target"] as? Double,
           targetBG != currentTarget
        {
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
            tempTargetActive: tempTargetActive, tempTargetText: tempTargetText,
            recommendedBolus: nil, isf: isf, carbRatio: carbRatio, currentTarget: currentTarget,
            autosensRatio: autosensRatio, eventualBG: eventualBG, tdd: tdd,
            minPredBG: minPredBG, maxPredBG: maxPredBG,
            insulinReq: insulinReq, reason: reasonText
        )

        DispatchQueue.main.async {
            self.loopStatus = status
            self.pendingInsulin = 0
            self.statusMatchesScroll = true
            self.updateScheduledBasal(for: timestamp)
            self.updateRecommendedBolus()
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

    func updateWidgetData() {
        guard let bg = currentBG else { return }
        let cutoff = Date().addingTimeInterval(-3.5 * 3600)
        let recentHistory = bgHistory.filter { $0.timestamp > cutoff }
        let points = recentHistory.map { WidgetBGPoint(value: $0.bgValue, timestamp: $0.timestamp) }
        let data = WidgetData(
            bgValue: bg.bgValue,
            direction: bg.direction,
            delta: bg.delta,
            bgTimestamp: bg.timestamp,
            iob: loopStatus?.iob,
            cob: loopStatus?.cob,
            basalRate: loopStatus?.basalRate,
            scheduledBasal: scheduledBasal,
            history: points,
            units: currentConfig?.units ?? "mg/dL",
            updatedAt: Date()
        )
        data.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "BGComplication")

        // Re-arm the foreground timer and the background refresh chain based
        // on the reading we just wrote, so the next fetch lands right after
        // the next reading is expected on Nightscout.
        rearmForegroundTimer(after: bg.timestamp)
        ExtensionDelegate.scheduleBackgroundRefresh()
    }

    func lookupScheduleValue(_ schedule: [(timeAsSeconds: Double, value: Double)]) -> Double? {
        guard !schedule.isEmpty else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = profileTimezone
        let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let currentSeconds = Double(components.hour ?? 0) * 3600 + Double(components.minute ?? 0) * 60 + Double(components.second ?? 0)

        var result: Double?
        for entry in schedule {
            if currentSeconds >= entry.timeAsSeconds {
                result = entry.value
            }
        }
        return result ?? schedule.last?.value
    }

    func updateRecommendedBolus() {
        // For Loop: use the pre-calculated recommendedBolus from devicestatus if available
        if let recBolus = loopStatus?.recommendedBolus {
            recommendedBolus = max(0, recBolus - pendingInsulin)
            bolusCalc = nil
            return
        }

        // For OpenAPS (or fallback): calculate from ISF, CR, target
        guard let bg = currentBG?.bgValue else {
            recommendedBolus = 0
            bolusCalc = nil
            return
        }

        // Prefer autosens-adjusted values from devicestatus, fall back to profile schedule
        guard let isf = loopStatus?.isf ?? lookupScheduleValue(isfSchedule), isf > 0 else {
            recommendedBolus = 0
            bolusCalc = nil
            return
        }
        let cr = loopStatus?.carbRatio ?? lookupScheduleValue(carbRatioSchedule)
        let target = loopStatus?.currentTarget ?? lookupScheduleValue(targetSchedule) ?? 100
        let iob = (loopStatus?.iob ?? 0) + pendingInsulin
        let cob = loopStatus?.cob ?? 0

        // Use 15-minute delta: find the BG reading closest to 15 minutes ago
        let delta: Double = {
            guard let currentTS = currentBG?.timestamp else { return Double(currentBG?.delta ?? 0) }
            let target15m = currentTS.addingTimeInterval(-15 * 60)
            var closest: BGReading?
            var closestDiff = Double.greatestFiniteMagnitude
            for reading in bgHistory {
                let diff = abs(reading.timestamp.timeIntervalSince(target15m))
                if diff < closestDiff {
                    closestDiff = diff
                    closest = reading
                }
            }
            // Only use if within 7.5 minutes of the 15m mark
            if let prior = closest, closestDiff < 7.5 * 60 {
                return Double(bg - prior.bgValue)
            }
            return Double(currentBG?.delta ?? 0)
        }()

        // Floor-round division results to 0.01 (safety rounding — always rounds down)
        let glucoseEffect = floor((Double(bg) - target) / isf * 100) / 100
        let iobEffect = -iob // no rounding — already a concrete value
        let totalCarbs = cob + pendingCarbs
        let cobEffect = (cr != nil && cr! > 0) ? floor(totalCarbs / cr! * 100) / 100 : 0
        let deltaEffect = floor(delta / isf * 100) / 100

        let fullBolus = glucoseEffect + iobEffect + cobEffect + deltaEffect
        // Round to 2 decimals to match displayed value, then floor to nearest 0.05
        let roundedBolus = (fullBolus * 100).rounded() / 100
        recommendedBolus = max(0, floor(roundedBolus * 20) / 20)

        bolusCalc = BolusCalculation(
            bg: Double(bg), target: target, isf: isf,
            iob: iob, cob: cob, pendingCarbs: pendingCarbs,
            cr: cr ?? 0, delta: delta,
            glucoseEffect: glucoseEffect, iobEffect: iobEffect,
            cobEffect: cobEffect, deltaEffect: deltaEffect,
            fullBolus: fullBolus
        )
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

        // Profile metadata surfaced in the Follow Status sheet
        let nameForDisplay = defaultProfileName
        let dia = defaultStore?["dia"] as? Double

        // Local copies — assigned to @Published properties on main below.
        var newBasalSchedule: [(timeAsSeconds: Double, value: Double)] = basalSchedule
        var newISFSchedule: [(timeAsSeconds: Double, value: Double)] = isfSchedule
        var newCRSchedule: [(timeAsSeconds: Double, value: Double)] = carbRatioSchedule
        var newTargetSchedule: [(timeAsSeconds: Double, value: Double)] = targetSchedule
        var newTimezone: TimeZone = profileTimezone

        // Extract basal schedule from default store
        if let basalArray = defaultStore?["basal"] as? [[String: Any]] {
            var schedule: [(timeAsSeconds: Double, value: Double)] = []
            for entry in basalArray {
                guard let value = entry["value"] as? Double else { continue }
                let timeAsSeconds = entry["timeAsSeconds"] as? Double ?? 0
                schedule.append((timeAsSeconds: timeAsSeconds, value: value))
            }
            schedule.sort { $0.timeAsSeconds < $1.timeAsSeconds }
            newBasalSchedule = schedule
        }

        // Extract ISF schedule from default store
        if let sensArray = defaultStore?["sens"] as? [[String: Any]] {
            var schedule: [(timeAsSeconds: Double, value: Double)] = []
            for entry in sensArray {
                guard let value = entry["value"] as? Double else { continue }
                let timeAsSeconds = entry["timeAsSeconds"] as? Double ?? 0
                schedule.append((timeAsSeconds: timeAsSeconds, value: value))
            }
            schedule.sort { $0.timeAsSeconds < $1.timeAsSeconds }
            newISFSchedule = schedule
        }

        // Extract carb ratio schedule from default store
        if let crArray = defaultStore?["carbratio"] as? [[String: Any]] {
            var schedule: [(timeAsSeconds: Double, value: Double)] = []
            for entry in crArray {
                guard let value = entry["value"] as? Double else { continue }
                let timeAsSeconds = entry["timeAsSeconds"] as? Double ?? 0
                schedule.append((timeAsSeconds: timeAsSeconds, value: value))
            }
            schedule.sort { $0.timeAsSeconds < $1.timeAsSeconds }
            newCRSchedule = schedule
        }

        // Extract target BG schedule from default store
        if let targetArray = defaultStore?["target_low"] as? [[String: Any]] {
            var schedule: [(timeAsSeconds: Double, value: Double)] = []
            for entry in targetArray {
                guard let value = entry["value"] as? Double else { continue }
                let timeAsSeconds = entry["timeAsSeconds"] as? Double ?? 0
                schedule.append((timeAsSeconds: timeAsSeconds, value: value))
            }
            schedule.sort { $0.timeAsSeconds < $1.timeAsSeconds }
            newTargetSchedule = schedule
        }

        // Extract timezone
        if let tz = defaultStore?["timezone"] as? String,
           let timezone = TimeZone(identifier: tz)
        {
            newTimezone = timezone
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
           let overridePresetsArray = loopSettings["overridePresets"] as? [[String: Any]]
        {
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
           let overridePresetsArray = storeLoopSettings["overridePresets"] as? [[String: Any]]
        {
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
            self.basalSchedule = newBasalSchedule
            self.isfSchedule = newISFSchedule
            self.carbRatioSchedule = newCRSchedule
            self.targetSchedule = newTargetSchedule
            self.profileTimezone = newTimezone
            self.overridePresets = presets
            self.profileName = nameForDisplay
            self.profileDIA = dia
            // Update scheduled basal for current time
            self.updateScheduledBasal(for: Date())
            self.updateRecommendedBolus()
        }
    }

    // MARK: - Nightscout Treatments (Bolus, Carbs, Temp Targets, Overrides)

    private func fetchTreatments(config: WatchConfig) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/treatments.json"

        let cutoff = Date().addingTimeInterval(-25 * 3600)
        let formatter = ISO8601DateFormatter()

        var queryItems = [URLQueryItem]()
        if !config.nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: config.nsToken))
        }
        queryItems.append(URLQueryItem(name: "find[created_at][$gte]", value: formatter.string(from: cutoff)))
        let futureLimit = Date().addingTimeInterval(6 * 3600)
        queryItems.append(URLQueryItem(name: "find[created_at][$lte]", value: formatter.string(from: futureLimit)))
        components?.queryItems = queryItems

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data else { return }
            self.parseTreatments(data: data)
        }.resume()
    }

    /// Parse a Nightscout date string, matching the iPhone app's NightscoutUtils.parseDate logic.
    /// Handles: "2024-01-01T12:00:00.000Z", "2024-01-01T12:00:00+00:00", "2024-01-01T12:00:00", etc.
    private func parseNSDate(_ rawString: String) -> Date? {
        var s = rawString
        // Strip trailing Z
        if s.hasSuffix("Z") { s = String(s.dropLast()) }
        // Strip timezone offset like +00:00 or -05:00
        else if let range = s.range(of: "[\\+\\-]\\d{2}:\\d{2}$", options: .regularExpression) {
            s.removeSubrange(range)
        }
        // Strip fractional seconds like .000 or .123456
        s = s.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        df.locale = Locale(identifier: "en_US")
        df.timeZone = TimeZone(abbreviation: "UTC")
        return df.date(from: s)
    }

    private func parseTreatments(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let entries = json as? [[String: Any]]
        else { return }

        var newTreatments: [Treatment] = []
        var tempTargetRaw: [[String: Any]] = []
        var overrideRaw: [[String: Any]] = []
        var tempBasalRaw: [[String: Any]] = []
        var newCannulaChangeDate: Date?
        var newSensorChangeDate: Date?
        var newInsulinChangeDate: Date?

        // Step 1: Sort entries into categories, matching iPhone app event types exactly
        for entry in entries {
            guard let eventType = entry["eventType"] as? String else { continue }

            switch eventType {
            case "Pump Site Change", "Site Change":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr)
                {
                    if newCannulaChangeDate == nil || ts > newCannulaChangeDate! {
                        newCannulaChangeDate = ts
                    }
                }

            case "Sensor Start", "Sensor Change":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr)
                {
                    if newSensorChangeDate == nil || ts > newSensorChangeDate! {
                        newSensorChangeDate = ts
                    }
                }

            case "Insulin Change", "Insulin Cartridge Change":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr)
                {
                    if newInsulinChangeDate == nil || ts > newInsulinChangeDate! {
                        newInsulinChangeDate = ts
                    }
                }

            case "Correction Bolus", "Bolus", "External Insulin":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr)
                {
                    if let automatic = entry["automatic"] as? Bool, automatic {
                        if let insulin = entry["insulin"] as? Double, insulin > 0 {
                            newTreatments.append(Treatment(timestamp: ts, type: .smb, value: insulin))
                        }
                    } else {
                        if let insulin = entry["insulin"] as? Double, insulin > 0 {
                            newTreatments.append(Treatment(timestamp: ts, type: .bolus, value: insulin))
                        }
                    }
                }

            case "SMB":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr),
                   let insulin = entry["insulin"] as? Double, insulin > 0
                {
                    newTreatments.append(Treatment(timestamp: ts, type: .smb, value: insulin))
                }

            case "Meal Bolus":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr)
                {
                    if let insulin = entry["insulin"] as? Double, insulin > 0 {
                        newTreatments.append(Treatment(timestamp: ts, type: .bolus, value: insulin))
                    }
                    if let carbs = entry["carbs"] as? Double, carbs > 0 {
                        newTreatments.append(Treatment(timestamp: ts, type: .carbs, value: carbs))
                    }
                }

            case "Carb Correction":
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr),
                   let carbs = entry["carbs"] as? Double, carbs > 0
                {
                    newTreatments.append(Treatment(timestamp: ts, type: .carbs, value: carbs))
                }

            case "Temporary Override", "Exercise":
                overrideRaw.append(entry)

            case "Temporary Target":
                tempTargetRaw.append(entry)

            case "Temp Basal":
                tempBasalRaw.append(entry)

            default:
                // Generic bolus/carb fallback
                if let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                   let ts = parseNSDate(dateStr)
                {
                    if let insulin = entry["insulin"] as? Double, insulin > 0 {
                        newTreatments.append(Treatment(timestamp: ts, type: .bolus, value: insulin))
                    }
                    if let carbs = entry["carbs"] as? Double, carbs > 0 {
                        newTreatments.append(Treatment(timestamp: ts, type: .carbs, value: carbs))
                    }
                }
            }
        }

        // Step 2: Process temp targets (matching iPhone app TemporaryTarget.swift)
        var newTempTargets: [TempTargetEntry] = []
        for entry in tempTargetRaw.reversed() {
            guard let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                  let startDate = parseNSDate(dateStr)
            else { continue }

            let duration = (entry["duration"] as? Double ?? 5.0) * 60 // seconds

            // duration 0 = cancellation marker: cap the previous active temp target
            if duration == 0 {
                let cancelTime = startDate.timeIntervalSince1970
                if let idx = newTempTargets.lastIndex(where: { $0.endDate.timeIntervalSince1970 > cancelTime }) {
                    newTempTargets[idx] = TempTargetEntry(
                        startDate: newTempTargets[idx].startDate,
                        endDate: startDate,
                        targetTop: newTempTargets[idx].targetTop,
                        targetBottom: newTempTargets[idx].targetBottom,
                        reason: newTempTargets[idx].reason
                    )
                }
                continue
            }

            if duration < 300 { continue } // skip < 5 min

            let low = entry["targetBottom"] as? Double
            let high = entry["targetTop"] as? Double
            guard let targetValue = low ?? high else { continue }

            let reason = entry["reason"] as? String ?? ""
            let endDate = startDate.addingTimeInterval(duration)
            newTempTargets.append(TempTargetEntry(
                startDate: startDate,
                endDate: endDate,
                targetTop: high ?? targetValue,
                targetBottom: low ?? targetValue,
                reason: reason
            ))
        }

        // Step 3: Process overrides (matching iPhone app Overrides.swift)
        let sortedOverrides = overrideRaw.sorted { lhs, rhs in
            guard let ls = lhs["timestamp"] as? String ?? lhs["created_at"] as? String,
                  let rs = rhs["timestamp"] as? String ?? rhs["created_at"] as? String,
                  let ld = parseNSDate(ls), let rd = parseNSDate(rs)
            else { return false }
            return ld < rd
        }

        var newOverrides: [OverrideEntry] = []
        let now = Date()
        let maxEndDate = now.addingTimeInterval(6 * 3600)

        for i in 0 ..< sortedOverrides.count {
            let e = sortedOverrides[i]
            guard let dateStr = e["timestamp"] as? String ?? e["created_at"] as? String,
                  let startDate = parseNSDate(dateStr)
            else { continue }

            var endDate: Date
            if (e["durationType"] as? String) == "indefinite" {
                endDate = maxEndDate
            } else {
                let durationMin = e["duration"] as? Double ?? 5
                endDate = startDate.addingTimeInterval(durationMin * 60)
            }

            // Cap at next override start to prevent overlap
            if i + 1 < sortedOverrides.count,
               let nextDateStr = sortedOverrides[i + 1]["timestamp"] as? String ?? sortedOverrides[i + 1]["created_at"] as? String,
               let nextStart = parseNSDate(nextDateStr)
            {
                if endDate > nextStart.addingTimeInterval(-60) {
                    endDate = nextStart.addingTimeInterval(-60)
                }
            }

            if endDate > maxEndDate { endDate = maxEndDate }
            if endDate.timeIntervalSince(startDate) < 300 { continue } // skip < 5 min

            let scaleFactor = e["insulinNeedsScaleFactor"] as? Double
            let overrideName = e["notes"] as? String ?? e["reason"] as? String ?? ""
            newOverrides.append(OverrideEntry(
                startDate: startDate,
                endDate: endDate,
                percentage: scaleFactor.map { $0 * 100 },
                name: overrideName
            ))
        }

        // Sum of carb treatments whose timestamp is in the device's calendar today.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
        let newCarbsToday = newTreatments
            .filter { $0.type == .carbs && $0.timestamp >= today && $0.timestamp < tomorrow }
            .reduce(0.0) { $0 + $1.value }

        // Find the temp basal that's still running right now and surface its
        // `absolute` value. This matches what the iPhone Follow app shows for
        // the basal info row — see LoopFollow/Controllers/Nightscout/Treatments/
        // Basals.swift, which uses `absolute` from the latest active Temp Basal
        // record. Differs from devicestatus.enacted.rate when the pump rounds.
        let nowDate = Date()
        let parsedTempBasals: [(start: Date, absolute: Double, duration: Double)] =
            tempBasalRaw.compactMap { entry in
                guard let dateStr = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                      let ts = parseNSDate(dateStr),
                      let absolute = entry["absolute"] as? Double else { return nil }
                let duration = entry["duration"] as? Double ?? 0
                return (ts, absolute, duration)
            }
            .sorted { $0.start < $1.start }
        var newCurrentTempBasal: Double?
        if let last = parsedTempBasals.last {
            let endTime = last.start.addingTimeInterval(last.duration * 60)
            if endTime > nowDate {
                newCurrentTempBasal = last.absolute
            }
        }

        DispatchQueue.main.async {
            self.treatments = newTreatments
            self.tempTargetEntries = newTempTargets
            self.overrideEntries = newOverrides
            self.cannulaChangeDate = newCannulaChangeDate
            self.sensorChangeDate = newSensorChangeDate
            self.insulinChangeDate = newInsulinChangeDate
            self.carbsToday = newCarbsToday
            self.currentTempBasal = newCurrentTempBasal
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
            fallbackToNightscout(config: config, dexError: "No Dexcom readings")
            return
        }

        DispatchQueue.main.async {
            self.bgHistory = readings
            self.currentBG = readings.first
            self.isReloading = false
            self.lastError = nil
            self.activeSource = "Dexcom"
            self.updateWidgetData()
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
