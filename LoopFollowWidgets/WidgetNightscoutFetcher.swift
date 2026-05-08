// LoopFollow
// WidgetNightscoutFetcher.swift
//
// Lightweight Nightscout BG fetcher for the widget extension. Fetches only the
// 3 most recent entries (count=3) and merges any new readings into the cached
// WidgetData. This runs inside getTimeline(), which the system calls every ~5
// minutes for an active complication — giving us a reliable update path that
// doesn't depend on the watch app's background task budget.

import Foundation

enum WidgetNightscoutFetcher {

    /// Result of a widget-side fetch attempt.
    enum FetchResult {
        case updated(WidgetData)   // new reading(s) merged into cache
        case unchanged(WidgetData) // cache was already current
        case failed(WidgetData?)   // network/parse error; returns cache if available
    }

    /// Fetch the latest 3 entries from Nightscout, merge into cached WidgetData,
    /// and return the result. Completes on an arbitrary queue.
    static func fetch(timeout: TimeInterval = 4, completion: @escaping (FetchResult) -> Void) {
        let shared = UserDefaults(suiteName: WidgetData.appGroupID) ?? .standard
        let nsURL = shared.string(forKey: "nsURL") ?? ""
        let nsToken = shared.string(forKey: "nsToken") ?? ""

        guard !nsURL.isEmpty else {
            completion(.failed(WidgetData.load()))
            return
        }

        var components = URLComponents(string: nsURL)
        components?.path = "/api/v1/entries.json"

        var queryItems = [URLQueryItem]()
        if !nsToken.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: nsToken))
        }
        queryItems.append(URLQueryItem(name: "count", value: "3"))
        queryItems.append(URLQueryItem(name: "find[type][$ne]", value: "cal"))
        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(.failed(WidgetData.load()))
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout

        URLSession.shared.dataTask(with: request) { data, _, error in
            if error != nil {
                completion(.failed(WidgetData.load()))
                return
            }

            guard let data = data else {
                completion(.failed(WidgetData.load()))
                return
            }

            let result = mergeResponse(data: data)
            completion(result)
        }.resume()
    }

    // MARK: - Parsing + merge

    private struct NSEntry: Decodable {
        var sgv: Double?
        var mbg: Double?
        var glucose: Double?
        var date: TimeInterval    // epoch millis
        var direction: String?

        var bgValue: Int? {
            if let sgv = sgv { return Int(sgv.rounded()) }
            if let mbg = mbg { return Int(mbg.rounded()) }
            if let glucose = glucose { return Int(glucose.rounded()) }
            return nil
        }

        var timestamp: Date {
            Date(timeIntervalSince1970: date / 1000)
        }
    }

    private static let directionMap: [String: String] = [
        "DoubleUp": "↑↑", "SingleUp": "↑", "FortyFiveUp": "↗",
        "Flat": "→", "FortyFiveDown": "↘", "SingleDown": "↓",
        "DoubleDown": "↓↓", "NOT COMPUTABLE": "-", "RATE OUT OF RANGE": "-",
        "NONE": "-", "": "-"
    ]

    private static func mergeResponse(data: Data) -> FetchResult {
        let cache = WidgetData.load()

        guard let entries = try? JSONDecoder().decode([NSEntry].self, from: data),
              let latest = entries.first,
              let latestBG = latest.bgValue else {
            return .failed(cache)
        }

        let latestTimestamp = latest.timestamp

        // If cache already has this reading (or newer), nothing to do.
        if let cache = cache, cache.bgTimestamp >= latestTimestamp {
            return .unchanged(cache)
        }

        // Compute delta from the 2nd entry if available, else from cache.
        let delta: Int?
        if entries.count >= 2, let prevBG = entries[1].bgValue {
            delta = latestBG - prevBG
        } else if let cache = cache {
            delta = latestBG - cache.bgValue
        } else {
            delta = nil
        }

        let direction = directionMap[latest.direction ?? ""] ?? "-"

        // Build new points from fetched entries.
        let newPoints = entries.compactMap { entry -> WidgetBGPoint? in
            guard let bg = entry.bgValue else { return nil }
            return WidgetBGPoint(value: bg, timestamp: entry.timestamp)
        }

        // Merge with cached history: new points + existing, dedupe by timestamp,
        // trim to 3.5 hours.
        let cutoff = Date().addingTimeInterval(-3.5 * 3600)
        let existingHistory = cache?.history ?? []

        // Combine, removing duplicates (same timestamp within 1s).
        var seen = Set<Int>() // epoch seconds as dedup key
        var merged: [WidgetBGPoint] = []
        for point in newPoints + existingHistory {
            let key = Int(point.timestamp.timeIntervalSince1970)
            if point.timestamp > cutoff && seen.insert(key).inserted {
                merged.append(point)
            }
        }
        merged.sort { $0.timestamp > $1.timestamp } // newest first

        let updated = WidgetData(
            bgValue: latestBG,
            direction: direction,
            delta: delta,
            bgTimestamp: latestTimestamp,
            iob: cache?.iob,
            cob: cache?.cob,
            basalRate: cache?.basalRate,
            scheduledBasal: cache?.scheduledBasal,
            history: merged,
            units: cache?.units ?? "mg/dL",
            updatedAt: Date()
        )
        updated.save()

        return .updated(updated)
    }
}
