// LoopFollow
// DeviceStatusHistoryState.swift

import Foundation

/// The cached device status history and the span of Nightscout records it
/// covers. Pure value logic; DeviceStatusHistory owns I/O and networking.
struct DeviceStatusHistoryState: Codable, Equatable {
    struct FetchRange: Equatable {
        let from: TimeInterval
        let to: TimeInterval
    }

    /// Ascending by date, one sample per loop cycle.
    private(set) var samples: [DeviceStatusHistorySample] = []
    /// Every record whose `created_at` falls in `coverageStart ... coverageEnd`
    /// has been fetched.
    private(set) var coverageStart: TimeInterval?
    private(set) var coverageEnd: TimeInterval?

    /// A new record this close to the covered span extends it without a fetch:
    /// loops upload every five minutes.
    static let gapTolerance: TimeInterval = 6.5 * 60
    /// Fetched ranges re-read this much of the covered span so a record written
    /// right at the edge is not missed.
    static let overlap: TimeInterval = 60

    var isEmpty: Bool { samples.isEmpty && coverageStart == nil }

    /// Inserts samples, replacing any existing sample from the same second.
    mutating func merge(_ newSamples: [DeviceStatusHistorySample]) {
        guard !newSamples.isEmpty else { return }
        var byKey: [Int: DeviceStatusHistorySample] = [:]
        byKey.reserveCapacity(samples.count + newSamples.count)
        for sample in samples {
            byKey[Int(sample.date.rounded())] = sample
        }
        for sample in newSamples {
            byKey[Int(sample.date.rounded())] = sample
        }
        samples = byKey.values.sorted { $0.date < $1.date }
    }

    /// Records that `from ... to` has been fetched. A range that neither
    /// overlaps nor touches the covered span replaces it.
    mutating func markCovered(from: TimeInterval, to: TimeInterval) {
        guard to >= from else { return }
        if let start = coverageStart, let end = coverageEnd,
           from <= end + Self.gapTolerance, to >= start - Self.gapTolerance
        {
            coverageStart = min(start, from)
            coverageEnd = max(end, to)
        } else {
            coverageStart = from
            coverageEnd = to
        }
    }

    /// Adds the record the regular device status poll just read, when it
    /// continues the covered span. Returns false when there is a gap to fetch.
    mutating func appendLatest(_ sample: DeviceStatusHistorySample, createdAt: TimeInterval) -> Bool {
        guard let start = coverageStart, let end = coverageEnd,
              createdAt >= start, createdAt <= end + Self.gapTolerance
        else { return false }
        merge([sample])
        coverageEnd = max(end, createdAt)
        return true
    }

    /// Drops samples before `cutoff` and shrinks the covered span to match.
    mutating func prune(before cutoff: TimeInterval) {
        if let firstKept = samples.firstIndex(where: { $0.date >= cutoff }) {
            if firstKept > 0 { samples.removeFirst(firstKept) }
        } else {
            samples.removeAll()
        }
        if let end = coverageEnd, end < cutoff {
            coverageStart = nil
            coverageEnd = nil
        } else if let start = coverageStart, start < cutoff {
            coverageStart = cutoff
        }
    }

    /// Ranges still to fetch so the history spans `windowStart` up to
    /// `latest`, the newest record known to exist.
    func missingRanges(windowStart: TimeInterval, latest: TimeInterval, now: TimeInterval) -> [FetchRange] {
        guard let start = coverageStart, let end = coverageEnd, end >= windowStart else {
            return [FetchRange(from: windowStart, to: now)]
        }
        var ranges: [FetchRange] = []
        if latest > end + Self.gapTolerance {
            // An uploader clock ahead of the phone can stamp records after `now`.
            ranges.append(FetchRange(from: end - Self.overlap, to: max(now, latest)))
        }
        if windowStart < start - Self.gapTolerance {
            ranges.append(FetchRange(from: windowStart, to: start + Self.overlap))
        }
        return ranges
    }

    /// The sample of the loop cycle nearest `date`, within `tolerance`.
    func sample(near date: TimeInterval, tolerance: TimeInterval) -> DeviceStatusHistorySample? {
        guard let index = nearestIndex(to: date) else { return nil }
        let sample = samples[index]
        return abs(sample.date - date) <= tolerance ? sample : nil
    }

    /// The loop cycle that ran on a BG reading at `readingDate`: the first cycle
    /// at or after the reading (allowing a little clock skew), within one cycle.
    func cycle(forReadingAt readingDate: TimeInterval) -> DeviceStatusHistorySample? {
        let earliest = readingDate - 60
        let latest = readingDate + Self.gapTolerance
        var lo = 0
        var hi = samples.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if samples[mid].date < earliest { lo = mid + 1 } else { hi = mid }
        }
        guard lo < samples.count, samples[lo].date <= latest else { return nil }
        return samples[lo]
    }

    private func nearestIndex(to date: TimeInterval) -> Int? {
        guard !samples.isEmpty else { return nil }
        var lo = 0
        var hi = samples.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if samples[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        if lo == samples.count { return samples.count - 1 }
        if lo == 0 { return 0 }
        return date - samples[lo - 1].date <= samples[lo].date - date ? lo - 1 : lo
    }
}
