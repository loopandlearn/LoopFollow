// LoopFollow
// SmoothedBgHistory.swift

import Foundation

struct SmoothedBgPoint {
    let time: TimeInterval
    let bgMgdl: Double
}

/// Decodable view of a single Nightscout devicestatus record, narrowed to just the
/// fields needed to extract OpenAPS/Trio's smoothed BG. Unrecognized JSON keys are
/// ignored by JSONDecoder, so the full devicestatus payload is parsed cheaply —
/// no nested predictions / IOB / COB tree is materialized.
private struct DeviceStatusBgRecord: Decodable {
    let created_at: String?
    let openaps: OpenAPSBlock?

    struct OpenAPSBlock: Decodable {
        let suggested: BgInner?
        let enacted: BgInner?
    }

    struct BgInner: Decodable {
        let bg: Double?
        let timestamp: String?
    }

    func point(formatter: ISO8601DateFormatter) -> SmoothedBgPoint? {
        let inner = openaps?.suggested ?? openaps?.enacted
        guard let bg = inner?.bg else { return nil }

        let raw = inner?.timestamp ?? created_at
        guard let ts = raw, let t = formatter.date(from: ts)?.timeIntervalSince1970 else { return nil }
        return SmoothedBgPoint(time: t, bgMgdl: bg)
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

        // Mark as fetched up-front so the gating check in DeviceStatus.swift doesn't
        // re-enter while this request is in flight. Reset on failure below.
        hasFetchedSmoothedBgHistory = true
        lastSmoothedBgBulkRefreshAt = Date()

        let days = max(1, Storage.shared.downloadDays.value)
        let count = days * 24 * 12 + 24
        let startMs = Int(Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970 * 1000)

        let parameters: [String: String] = [
            "count": "\(count)",
            "find[created_at][$gte]": "\(startMs)",
        ]

        NightscoutUtils.executeRequest(eventType: .deviceStatus, parameters: parameters) { [weak self] (result: Result<[DeviceStatusBgRecord], Error>) in
            switch result {
            case let .success(records):
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

                var seen = Set<Int>()
                var points: [SmoothedBgPoint] = []
                points.reserveCapacity(records.count)
                for record in records {
                    guard let p = record.point(formatter: formatter) else { continue }
                    // Dedup by integer-second to collapse near-duplicate enacted/suggested rows.
                    if seen.insert(Int(p.time)).inserted {
                        points.append(p)
                    }
                }

                DispatchQueue.main.async {
                    guard let self = self else { return }
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

            case let .failure(error):
                LogManager.shared.log(category: .deviceStatus, message: "Smoothed BG history fetch failed: \(error.localizedDescription)", limitIdentifier: "Smoothed BG history fetch failed")
                DispatchQueue.main.async {
                    // Allow retry on the next devicestatus cycle.
                    self?.hasFetchedSmoothedBgHistory = false
                }
            }
        }
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
        guard !smoothedBgData.isEmpty else { return nil }
        var best: SmoothedBgPoint?
        var bestDiff = tolerance
        for p in smoothedBgData {
            let diff = abs(p.time - time)
            if diff <= bestDiff {
                best = p
                bestDiff = diff
            }
            if p.time - time > tolerance { break }
        }
        return best?.bgMgdl
    }
}
