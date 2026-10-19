// LoopFollow
// StandaloneFetcher.swift

import Foundation

/// Builds the watch state straight from Nightscout or Dexcom while the phone is
/// out of reach. What only the phone knows (info rows, presets, guardrails,
/// thresholds) is kept from the last state the phone sent.
enum StandaloneFetcher {
    enum FetchError: LocalizedError {
        case noDataSource
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noDataSource: "No Nightscout or Dexcom account on the watch yet."
            case .badResponse: "Unexpected response from the data source."
            }
        }
    }

    private static let history: TimeInterval = 24 * 3600
    /// How far ahead predictions are drawn.
    private static let predictionPoints = 36

    static func fetch(credentials: WatchCredentials, base: WatchState?, now: Date = Date()) async throws -> WatchState {
        if !credentials.nightscoutURL.isEmpty {
            return try await fetchNightscout(credentials: credentials, base: base, now: now)
        }
        if !credentials.dexcomUsername.isEmpty, !credentials.dexcomPassword.isEmpty {
            return try await fetchDexcom(credentials: credentials, base: base, now: now)
        }
        throw FetchError.noDataSource
    }

    // MARK: - Nightscout

    private static func fetchNightscout(credentials: WatchCredentials, base: WatchState?, now: Date) async throws -> WatchState {
        let since = now.addingTimeInterval(-history)
        async let entries = get(credentials, "/api/v1/entries.json", [
            "find[date][$gte]": String(Int(since.timeIntervalSince1970 * 1000)),
            "find[type][$ne]": "cal",
            "count": "400",
        ])
        async let deviceStatus = get(credentials, "/api/v1/devicestatus.json", ["count": "1"])
        async let treatments = get(credentials, "/api/v1/treatments.json", [
            "find[created_at][$gte]": iso.string(from: since),
            "count": "500",
        ])

        let glucose = try JSONDecoder().decode([ShareGlucoseData].self, from: await entries)
            .filter { $0.sgv > 0 }
            .sorted { $0.date < $1.date }
        let status = (try? JSONSerialization.jsonObject(with: await deviceStatus) as? [[String: Any]])?.first
        let treatmentList = (try? JSONSerialization.jsonObject(with: await treatments) as? [[String: Any]]) ?? []

        return build(glucose: glucose, status: status.map { parseDeviceStatus($0, base: base) }, treatments: treatmentList, base: base, now: now)
    }

    private static func get(_ credentials: WatchCredentials, _ path: String, _ parameters: [String: String]) async throws -> Data {
        var components = URLComponents(string: credentials.nightscoutURL)
        components?.path = path
        var items = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        if !credentials.nightscoutToken.isEmpty {
            items.append(URLQueryItem(name: "token", value: credentials.nightscoutToken))
        }
        components?.queryItems = items
        guard let url = components?.url else { throw FetchError.badResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.badResponse }
        return data
    }

    // MARK: - Dexcom

    private static func fetchDexcom(credentials: WatchCredentials, base: WatchState?, now: Date) async throws -> WatchState {
        let server = credentials.dexcomServer == "US" ? KnownShareServers.US.rawValue : KnownShareServers.NON_US.rawValue
        let client = ShareClient(username: credentials.dexcomUsername, password: credentials.dexcomPassword, shareServer: server)
        let glucose: [ShareGlucoseData] = try await withCheckedThrowingContinuation { continuation in
            client.fetchData(288) { error, data in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? FetchError.badResponse)
                }
            }
        }
        return build(glucose: glucose.sorted { $0.date < $1.date }, status: nil, treatments: [], base: base, now: now)
    }

    // MARK: - Building

    struct LoopStatus {
        var loopAt: Date?
        var iob: Double?
        var cob: Double?
        var recommendedBolus: Double?
        var predictions: [WatchPredictionLine] = []
        var cone: [WatchConePoint] = []
    }

    private static func build(glucose: [ShareGlucoseData], status: LoopStatus?, treatments: [[String: Any]], base: WatchState?, now: Date) -> WatchState {
        let cutoff = now.timeIntervalSince1970 - history
        let readings = glucose.filter { $0.date >= cutoff }.map { WatchReading(t: $0.date, v: Double($0.sgv)) }
        let latest = glucose.last
        let previous = glucose.dropLast().last

        let active = activeAdjustments(treatments, now: now)
        var snapshot: GlucoseSnapshot?
        if let latest {
            let loopAge = status?.loopAt.map { now.timeIntervalSince($0) }
            snapshot = GlucoseSnapshot(
                glucose: Double(latest.sgv),
                delta: previous.map { Double(latest.sgv - $0.sgv) } ?? 0,
                trend: GlucoseSnapshot.Trend(code: latest.direction),
                updatedAt: Date(timeIntervalSince1970: latest.date),
                iob: status?.iob,
                cob: status?.cob,
                projected: nil,
                override: active.override,
                tempTargetMgdl: active.tempTargetMgdl,
                recBolus: status?.recommendedBolus,
                unit: base?.snapshot?.unit ?? .mgdl,
                isNotLooping: loopAge.map { $0 >= 15 * 60 } ?? false
            )
        }

        var remote = base?.remote
        if remote != nil {
            remote?.recommendedBolus = status?.recommendedBolus
            remote?.recommendedBolusAt = status?.loopAt
        }

        return WatchState(
            builtAt: now,
            source: .watch,
            phoneBuiltAt: base?.phoneBuiltAt ?? .distantPast,
            snapshot: snapshot,
            readings: readings,
            predictions: status?.predictions ?? [],
            cone: status?.cone ?? [],
            boluses: treatments.compactMap { reading($0, key: "insulin", cutoff: cutoff) }.sorted { $0.t < $1.t },
            carbs: treatments.compactMap { reading($0, key: "carbs", cutoff: cutoff) }.sorted { $0.t < $1.t },
            lowMgdl: base?.lowMgdl ?? 70,
            highMgdl: base?.highMgdl ?? 180,
            colorBGText: base?.colorBGText ?? true,
            infoRows: base?.infoRows ?? [],
            lastLoopAt: status?.loopAt,
            device: base?.device ?? "",
            alarm: nil,
            remote: remote
        )
    }

    /// Reads the loop's latest report the same way the phone does: `loop` for Loop, `openaps` for Trio.
    static func parseDeviceStatus(_ status: [String: Any], base: WatchState?) -> LoopStatus {
        var result = LoopStatus()
        if let loop = status["loop"] as? [String: Any] {
            result.loopAt = date(loop["timestamp"])
            result.iob = (loop["iob"] as? [String: Any])?["iob"] as? Double
            result.cob = (loop["cob"] as? [String: Any])?["cob"] as? Double
            result.recommendedBolus = loop["recommendedBolus"] as? Double
            if let predicted = loop["predicted"] as? [String: Any],
               let values = predicted["values"] as? [Double],
               let start = date(predicted["startDate"])
            {
                result.predictions = [WatchPredictionLine(kind: .loop, points: points(values, start: start))]
            }
        } else if let openaps = status["openaps"] as? [String: Any] {
            let suggested = openaps["suggested"] as? [String: Any] ?? openaps["enacted"] as? [String: Any] ?? [:]
            result.loopAt = date(suggested["deliverAt"] ?? suggested["timestamp"])
            let iob = openaps["iob"] as? [String: Any] ?? (openaps["iob"] as? [[String: Any]])?.first
            result.iob = iob?["iob"] as? Double ?? suggested["IOB"] as? Double
            result.cob = suggested["COB"] as? Double
            result.recommendedBolus = openaps["recommendedBolus"] as? Double
            if let predBGs = suggested["predBGs"] as? [String: [Double]], let start = result.loopAt {
                let lines: [(WatchPredictionLine.Kind, String)] = [(.zt, "ZT"), (.iob, "IOB"), (.cob, "COB"), (.uam, "UAM")]
                let series = lines.compactMap { kind, key in predBGs[key].map { (kind, points($0, start: start)) } }
                // The phone shows Trio's forecast as a cone or as lines; keep what it showed last.
                if base?.cone.isEmpty == false {
                    result.cone = cone(series.map(\.1))
                } else {
                    result.predictions = series.map { WatchPredictionLine(kind: $0.0, points: $0.1) }
                }
            }
        }
        return result
    }

    private static func points(_ values: [Double], start: Date) -> [WatchReading] {
        values.prefix(predictionPoints + 1).enumerated().map { index, value in
            WatchReading(t: start.timeIntervalSince1970 + Double(index) * 300, v: value)
        }
    }

    /// Same construction as the phone: the shortest series sets the length, min and max per step.
    private static func cone(_ series: [[WatchReading]]) -> [WatchConePoint] {
        guard let length = series.map(\.count).min(), length > 0 else { return [] }
        return (0 ..< length).map { index in
            let values = series.map { $0[index].v }
            var low = values.min() ?? 0
            var high = values.max() ?? 0
            if low == high {
                low -= 1
                high += 1
            }
            return WatchConePoint(t: series[0][index].t, low: low, high: high)
        }
    }

    private static func reading(_ treatment: [String: Any], key: String, cutoff: TimeInterval) -> WatchReading? {
        guard let value = treatment[key] as? Double, value > 0,
              let at = date(treatment["timestamp"] ?? treatment["created_at"]),
              at.timeIntervalSince1970 >= cutoff
        else { return nil }
        return WatchReading(t: at.timeIntervalSince1970, v: value)
    }

    /// The override and temp target that are running now, from the latest of each in the treatments.
    private static func activeAdjustments(_ treatments: [[String: Any]], now: Date) -> (override: String?, tempTargetMgdl: Double?) {
        func latest(_ eventType: String) -> (start: Date, entry: [String: Any])? {
            treatments
                .filter { $0["eventType"] as? String == eventType }
                .compactMap { entry in date(entry["timestamp"] ?? entry["created_at"]).map { ($0, entry) } }
                .max { $0.0 < $1.0 }
        }

        var override: String?
        if let (start, entry) = latest("Temporary Override") {
            let minutes = entry["duration"] as? Double ?? 0
            let indefinite = minutes == 0 || (entry["durationType"] as? String) == "indefinite"
            if start <= now, indefinite || now < start.addingTimeInterval(minutes * 60) {
                override = entry["reason"] as? String ?? entry["notes"] as? String ?? "Override"
            }
        }

        var tempTarget: Double?
        if let (start, entry) = latest("Temporary Target") {
            let minutes = entry["duration"] as? Double ?? 0
            if minutes > 0, start <= now, now < start.addingTimeInterval(minutes * 60) {
                tempTarget = entry["targetTop"] as? Double ?? entry["targetBottom"] as? Double
            }
        }
        return (override, tempTarget)
    }

    // MARK: - Dates

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoNoFraction = ISO8601DateFormatter()

    private static func date(_ value: Any?) -> Date? {
        if let number = value as? Double {
            return Date(timeIntervalSince1970: number > 1e11 ? number / 1000 : number)
        }
        guard let string = value as? String else { return nil }
        return iso.date(from: string) ?? isoNoFraction.date(from: string)
    }
}
