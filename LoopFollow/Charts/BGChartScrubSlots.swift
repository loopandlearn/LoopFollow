// LoopFollow
// BGChartScrubSlots.swift

import Foundation

/// Five-minute grid, phase-locked to the readings, that the scrub indicator
/// snaps to.
///
/// The grid is walked backwards from the newest reading. Each step lands on
/// the reading nearest the expected mark when one lies within half a cadence
/// of it, and on a virtual mark otherwise, so drift is absorbed and gaps are
/// crossed at exactly the cadence. The grid continues before the first and
/// after the last mark. Each mark owns the time between the midpoints to its
/// neighbours, so the blocks tile the timeline and every reading and
/// treatment belongs to exactly one mark.
struct BGChartScrubSlots {
    struct Slot: Equatable {
        let date: Date
        /// Index into `readingDates` for a mark placed on a reading; nil for a
        /// virtual mark.
        let readingIndex: Int?
        /// Owned time, inclusive at the start and exclusive at the end.
        let blockStart: Date
        let blockEnd: Date

        var isReading: Bool { readingIndex != nil }

        func contains(_ date: Date) -> Bool {
            date >= blockStart && date < blockEnd
        }
    }

    static let cadence: TimeInterval = 5 * 60

    /// Every reading timestamp, ascending.
    let readingDates: [Date]
    /// Grid marks inside the data range, ascending.
    private let slotDates: [Date]
    private let slotReadingIndices: [Int?]

    init(readingDates: [Date]) {
        let sorted = readingDates.sorted()
        self.readingDates = sorted

        var dates: [Date] = []
        var indices: [Int?] = []
        if let first = sorted.first, let newest = sorted.last {
            let cadence = Self.cadence
            var cursor = newest
            var cursorIndex = sorted.count - 1
            dates.append(cursor)
            indices.append(cursorIndex)
            while first < cursor.addingTimeInterval(-cadence / 2) {
                let target = cursor.addingTimeInterval(-cadence)
                if let hit = Self.nearestReading(in: sorted, before: cursorIndex, to: target, within: cadence / 2) {
                    cursor = sorted[hit]
                    cursorIndex = hit
                    dates.append(cursor)
                    indices.append(hit)
                } else {
                    cursor = target
                    dates.append(cursor)
                    indices.append(nil)
                }
            }
            dates.reverse()
            indices.reverse()
        }
        slotDates = dates
        slotReadingIndices = indices
    }

    /// Index of the reading nearest `target` among those strictly before index
    /// `limit`, if it lies within `tolerance` of the target.
    private static func nearestReading(in sorted: [Date], before limit: Int, to target: Date, within tolerance: TimeInterval) -> Int? {
        guard limit > 0 else { return nil }
        // First index in 0 ..< limit whose date is >= target.
        var low = 0
        var high = limit
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] < target { low = mid + 1 } else { high = mid }
        }
        var best: Int?
        for candidate in [low - 1, low] where candidate >= 0 && candidate < limit {
            let distance = abs(sorted[candidate].timeIntervalSince(target))
            if distance <= tolerance, best.map({ distance < abs(sorted[$0].timeIntervalSince(target)) }) ?? true {
                best = candidate
            }
        }
        return best
    }

    /// The mark whose block contains `date`.
    func slot(containing date: Date) -> Slot {
        let cadence = Self.cadence
        guard let firstSlot = slotDates.first, let lastSlot = slotDates.last else {
            return virtualSlot(origin: Date(timeIntervalSince1970: 0), nearestTo: date)
        }
        if date < firstSlot.addingTimeInterval(-cadence / 2) {
            return virtualSlot(origin: firstSlot, nearestTo: date)
        }
        if date >= lastSlot.addingTimeInterval(cadence / 2) {
            return virtualSlot(origin: lastSlot, nearestTo: date)
        }

        // Index of the last mark at or before `date`; the midpoint to its
        // successor decides between the two.
        var low = 0
        var high = slotDates.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if slotDates[mid] <= date { low = mid } else { high = mid - 1 }
        }
        var i = low
        if date < firstSlot {
            i = 0
        } else if i + 1 < slotDates.count, date >= midpoint(slotDates[i], slotDates[i + 1]) {
            i += 1
        }
        return gridSlot(at: i)
    }

    private func gridSlot(at i: Int) -> Slot {
        let cadence = Self.cadence
        let date = slotDates[i]
        let blockStart = i > 0 ? midpoint(slotDates[i - 1], date) : date.addingTimeInterval(-cadence / 2)
        let blockEnd = i + 1 < slotDates.count ? midpoint(date, slotDates[i + 1]) : date.addingTimeInterval(cadence / 2)
        return Slot(date: date, readingIndex: slotReadingIndices[i], blockStart: blockStart, blockEnd: blockEnd)
    }

    /// Virtual mark on the grid anchored at `origin`; a halfway date belongs
    /// to the later mark, matching the half-open blocks.
    private func virtualSlot(origin: Date, nearestTo date: Date) -> Slot {
        let cadence = Self.cadence
        let k = (date.timeIntervalSince(origin) / cadence + 0.5).rounded(.down)
        return Slot(
            date: origin.addingTimeInterval(k * cadence),
            readingIndex: nil,
            blockStart: origin.addingTimeInterval((k - 0.5) * cadence),
            blockEnd: origin.addingTimeInterval((k + 0.5) * cadence)
        )
    }

    private func midpoint(_ a: Date, _ b: Date) -> Date {
        a.addingTimeInterval(b.timeIntervalSince(a) / 2)
    }
}
