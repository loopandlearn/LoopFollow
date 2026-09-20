// LoopFollow
// SmoothedBgHistory.swift

import Foundation

struct SmoothedBgPoint: Equatable, Sendable {
    let time: TimeInterval
    let bgMgdl: Double
}

enum SmoothedBgSeries {
    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let timezoneLessFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func parseDate(_ rawString: String) -> Date? {
        if let date = fractionalISO8601Formatter.date(from: rawString)
            ?? iso8601Formatter.date(from: rawString)
        {
            return date
        }

        let withoutFraction = rawString.replacingOccurrences(
            of: "\\.\\d+$",
            with: "",
            options: .regularExpression
        )
        return timezoneLessFormatter.date(from: withoutFraction)
    }

    static func point(
        bg: Double,
        timestampCandidates: [String?]
    ) -> SmoothedBgPoint? {
        for candidate in timestampCandidates {
            guard let candidate, let date = parseDate(candidate) else { continue }
            return SmoothedBgPoint(time: date.timeIntervalSince1970, bgMgdl: bg)
        }
        return nil
    }

    static func nearestValue(
        in points: [SmoothedBgPoint],
        to time: TimeInterval,
        tolerance: TimeInterval = 150
    ) -> Double? {
        var best: SmoothedBgPoint?
        var bestDifference = tolerance

        for point in points {
            let difference = abs(point.time - time)
            if difference <= bestDifference {
                best = point
                bestDifference = difference
            }
            if point.time - time > tolerance { break }
        }

        return best?.bgMgdl
    }

    static func chartPoints(
        from points: [SmoothedBgPoint],
        startingAt start: TimeInterval,
        endingAt end: TimeInterval,
        minimumSpacing: TimeInterval = 240
    ) -> [SmoothedBgPoint] {
        var result: [SmoothedBgPoint] = []
        var lastKeptTime = -TimeInterval.infinity

        for point in points.sorted(by: { $0.time < $1.time })
            where point.time >= start && point.time <= end
        {
            guard point.time - lastKeptTime >= minimumSpacing else { continue }
            result.append(point)
            lastKeptTime = point.time
        }

        return result
    }
}

/// Decodable view of a single Nightscout devicestatus record, narrowed to just the
/// fields needed to extract OpenAPS/Trio's smoothed BG. Unrecognized JSON keys are
/// ignored by JSONDecoder, so the full devicestatus payload is parsed cheaply —
/// no nested predictions / IOB / COB tree is materialized.
struct DeviceStatusBgRecord: Decodable, Sendable {
    let createdAt: String?
    let openaps: OpenAPSBlock?

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case openaps
    }

    struct OpenAPSBlock: Decodable, Sendable {
        let suggested: BgInner?
        let enacted: BgInner?
    }

    struct BgInner: Decodable, Sendable {
        let bg: Double?
        let timestamp: String?
        let deliverAt: String?
    }

    func point() -> SmoothedBgPoint? {
        if let suggested = openaps?.suggested, let bg = suggested.bg {
            return point(
                bg: bg,
                timestampCandidates: [
                    suggested.deliverAt,
                    suggested.timestamp,
                    createdAt,
                    openaps?.enacted?.deliverAt,
                    openaps?.enacted?.timestamp,
                ]
            )
        }

        if let enacted = openaps?.enacted, let bg = enacted.bg {
            return point(
                bg: bg,
                timestampCandidates: [enacted.deliverAt, enacted.timestamp, createdAt]
            )
        }

        return nil
    }

    private func point(bg: Double, timestampCandidates: [String?]) -> SmoothedBgPoint? {
        SmoothedBgSeries.point(bg: bg, timestampCandidates: timestampCandidates)
    }
}

extension MainViewController {
    /// Fetches OpenAPS/Trio devicestatus records over the configured graph range and
    /// extracts each loop run's smoothed BG, so the chart-tap popup can show the
    /// smoothed value next to every glucose dot. Mirrors the BG-data fetch path:
    /// typed `Decodable` + `count` + `find[date][$gte]` + `executeRequest`.
    func webLoadNSSmoothedBgHistory() {
        guard Storage.shared.displaySmoothedBG.value else { return }
        guard IsNightscoutEnabled() else { return }
        guard Storage.shared.device.value != "Loop" else { return }

        let requestGeneration = smoothedBgFetchGeneration
        let requestURL = Storage.shared.url.value
        let requestToken = Storage.shared.token.value
        let requestDevice = Storage.shared.device.value

        // Mark as fetched up-front so the gating check in DeviceStatus.swift doesn't
        // re-enter while this request is in flight. Reset on failure below.
        hasFetchedSmoothedBgHistory = true
        lastSmoothedBgBulkRefreshAt = Date()

        let days = max(1, Storage.shared.downloadDays.value)
        let count = days * 24 * 12 + 24
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let startDate = Date().addingTimeInterval(-Double(days) * 86400)

        let parameters: [String: String] = [
            "count": "\(count)",
            "find[created_at][$gte]": formatter.string(from: startDate),
        ]

        NightscoutUtils.executeRequest(eventType: .deviceStatus, parameters: parameters) { [weak self] (result: Result<[DeviceStatusBgRecord], Error>) in
            switch result {
            case let .success(records):
                // executeRequest delivers successful decodes on the main queue.
                // Parse the potentially four-day history off-main, reusing the
                // formatters above instead of constructing one per record.
                DispatchQueue.global(qos: .userInitiated).async {
                    var parsedKeys = Set<Int>()
                    var parsedPoints: [SmoothedBgPoint] = []
                    parsedPoints.reserveCapacity(records.count)
                    for record in records {
                        guard let point = record.point() else { continue }
                        // Dedup by integer-second to collapse near-duplicate enacted/suggested rows.
                        if parsedKeys.insert(Int(point.time)).inserted {
                            parsedPoints.append(point)
                        }
                    }

                    DispatchQueue.main.async {
                        guard let self else { return }
                        guard self.smoothedBgFetchGeneration == requestGeneration,
                              Storage.shared.displaySmoothedBG.value,
                              Storage.shared.url.value == requestURL,
                              Storage.shared.token.value == requestToken,
                              Storage.shared.device.value == requestDevice
                        else { return }
                        var seen = parsedKeys
                        var points = parsedPoints
                        // Merge with anything appendSmoothedBgPoint added while the fetch was in flight.
                        for existing in self.smoothedBgData {
                            if seen.insert(Int(existing.time)).inserted {
                                points.append(existing)
                            }
                        }
                        points.sort { $0.time < $1.time }
                        self.smoothedBgData = points
                        self.updateBGGraph()
                    }
                }

            case let .failure(error):
                LogManager.shared.log(category: .deviceStatus, message: "Smoothed BG history fetch failed: \(error.localizedDescription)", limitIdentifier: "Smoothed BG history fetch failed")
                DispatchQueue.main.async {
                    // Allow retry on the next devicestatus cycle.
                    guard let self, self.smoothedBgFetchGeneration == requestGeneration else { return }
                    self.hasFetchedSmoothedBgHistory = false
                }
            }
        }
    }

    /// Invalidates both the visible cache and any in-flight bulk request. Call when
    /// the graph range or Nightscout identity changes, or when smoothing is disabled.
    func invalidateSmoothedBgCache() {
        smoothedBgFetchGeneration &+= 1
        smoothedBgData = []
        hasFetchedSmoothedBgHistory = false
        lastSmoothedBgBulkRefreshAt = nil
        infoManager.clearInfoData(type: .smoothedBg)
        updateBGGraph()
    }

    /// Merge a single freshly-parsed point into the in-memory history. Called after
    /// each devicestatus refresh so the latest reading always has a match without a
    /// new bulk fetch.
    func appendSmoothedBgPoint(time: TimeInterval, bgMgdl: Double) {
        guard Storage.shared.displaySmoothedBG.value else { return }
        let key = Int(time)
        if smoothedBgData.contains(where: { Int($0.time) == key }) { return }

        let previousLatestTime = smoothedBgData.last?.time
        smoothedBgData.append(SmoothedBgPoint(time: time, bgMgdl: bgMgdl))
        smoothedBgData.sort { $0.time < $1.time }

        // Drop entries older than the configured graph range to bound memory.
        let cutoff = Date().timeIntervalSince1970 - Double(max(1, Storage.shared.downloadDays.value)) * 86400
        if let firstKept = smoothedBgData.firstIndex(where: { $0.time >= cutoff }), firstKept > 0 {
            smoothedBgData.removeFirst(firstKept)
        }

        // Refresh the chart so the dot for this loop run picks up the smoothed
        // value immediately — without waiting for the next BG fetch cycle.
        updateBGGraph()

        // Gap detection: if the new point is far ahead of the previous latest,
        // we likely missed loop runs (Trio offline, network glitch, etc.). Trigger
        // a debounced bulk refresh so older dots can backfill their smoothed values
        // without needing a force-close + reopen.
        if let prev = previousLatestTime, time - prev > 360 {
            considerSmoothedBgGapRefresh()
        }
    }

    private func considerSmoothedBgGapRefresh() {
        let lastAge = lastSmoothedBgBulkRefreshAt.map { -$0.timeIntervalSinceNow } ?? .infinity
        guard lastAge >= 120 else { return } // debounce: max once per 2 min
        hasFetchedSmoothedBgHistory = false
        webLoadNSSmoothedBgHistory()
    }

    /// Look up the smoothed BG closest to the given timestamp. Returns nil if no
    /// recorded loop run is within the tolerance window.
    func smoothedBg(near time: TimeInterval, tolerance: TimeInterval = 150) -> Double? {
        SmoothedBgSeries.nearestValue(in: smoothedBgData, to: time, tolerance: tolerance)
    }
}
