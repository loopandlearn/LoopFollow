// LoopFollow
// BGChartScrubSlotsTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct BGChartScrubSlotsTests {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ minutes: Double) -> Date {
        origin.addingTimeInterval(minutes * 60)
    }

    private func minutes(_ date: Date) -> Double {
        date.timeIntervalSince(origin) / 60
    }

    private func slot(_ slot: BGChartScrubSlots.Slot, isAt minute: Double) -> Bool {
        abs(minutes(slot.date) - minute) < 0.001
    }

    @Test("five-minute readings are marks that own the time up to the midpoints")
    func denseReadingBlocks() {
        let slots = BGChartScrubSlots(readingDates: [0, 5, 10, 15].map(at))

        let second = slots.slot(containing: at(6))
        #expect(second.readingIndex == 1)
        #expect(second.date == at(5))
        #expect(minutes(second.blockStart) == 2.5)
        #expect(minutes(second.blockEnd) == 7.5)

        #expect(slots.slot(containing: at(7.4)).readingIndex == 1)
        #expect(slots.slot(containing: at(7.5)).readingIndex == 2)
    }

    @Test("one-minute readings snap to every fifth reading, anchored at the newest")
    func oneMinuteDataSnapsToFiveMinutes() {
        let slots = BGChartScrubSlots(readingDates: stride(from: 0.0, through: 22.0, by: 1.0).map(at))

        #expect(slot(slots.slot(containing: at(22)), isAt: 22))
        #expect(slot(slots.slot(containing: at(16)), isAt: 17))
        #expect(slot(slots.slot(containing: at(13)), isAt: 12))
        #expect(slot(slots.slot(containing: at(1)), isAt: 2))

        let seventeen = slots.slot(containing: at(16))
        #expect(seventeen.isReading)
        #expect(minutes(seventeen.blockStart) == 14.5)
        #expect(minutes(seventeen.blockEnd) == 19.5)
    }

    @Test("sensor drift keeps every reading on the grid")
    func driftFollowsReadings() {
        let slots = BGChartScrubSlots(readingDates: [0, 5.1, 10.2, 15.3, 20.4].map(at))
        for (index, minute) in [0, 5.1, 10.2, 15.3, 20.4].enumerated() {
            let mark = slots.slot(containing: at(minute))
            #expect(mark.readingIndex == index)
            #expect(slot(mark, isAt: minute))
        }
    }

    @Test("a straggler close to a grid reading joins its block")
    func stragglerJoinsBlock() {
        let slots = BGChartScrubSlots(readingDates: [0, 5, 5.2, 10].map(at))

        let mark = slots.slot(containing: at(5.2))
        #expect(mark.date == at(5))
        #expect(mark.contains(at(5.2)))
        #expect(slots.slot(containing: at(10)).date == at(10))
    }

    @Test("a gap is crossed at exactly the cadence from the reading that ends it")
    func gapUsesVirtualCadence() {
        let slots = BGChartScrubSlots(readingDates: [0, 5, 10, 33, 38, 43].map(at))

        for minute in [18.0, 23.0, 28.0] {
            let mark = slots.slot(containing: at(minute + 1))
            #expect(slot(mark, isAt: minute))
            #expect(mark.readingIndex == nil)
            #expect(mark.blockEnd.timeIntervalSince(mark.blockStart) == 300)
        }

        // The virtual mark next to the reading that resumes the data shares
        // the leftover with it at the midpoint.
        let edge = slots.slot(containing: at(14))
        #expect(slot(edge, isAt: 13))
        #expect(minutes(edge.blockStart) == 11.5)
        #expect(minutes(edge.blockEnd) == 15.5)

        let resumed = slots.slot(containing: at(9))
        #expect(resumed.readingIndex == 2)
        #expect(minutes(resumed.blockStart) == 7.5)
        #expect(minutes(resumed.blockEnd) == 11.5)
    }

    @Test("a reading just off the grid is used instead of a virtual mark")
    func nearReadingBeatsVirtualMark() {
        let slots = BGChartScrubSlots(readingDates: [0, 7, 30, 35].map(at))

        #expect(slot(slots.slot(containing: at(24)), isAt: 25))
        #expect(slot(slots.slot(containing: at(19)), isAt: 20))
        #expect(slot(slots.slot(containing: at(14)), isAt: 15))
        #expect(slot(slots.slot(containing: at(11)), isAt: 10))

        let seven = slots.slot(containing: at(6))
        #expect(seven.readingIndex == 1)
        #expect(slot(seven, isAt: 7))

        #expect(slots.slot(containing: at(3)).readingIndex == 0)
    }

    @Test("the grid continues at the cadence beyond the first and last marks")
    func gridExtendsBeyondReadings() {
        let slots = BGChartScrubSlots(readingDates: [0, 5, 10].map(at))

        let last = slots.slot(containing: at(12))
        #expect(last.readingIndex == 2)
        #expect(minutes(last.blockEnd) == 12.5)

        let future = slots.slot(containing: at(23))
        #expect(future.readingIndex == nil)
        #expect(slot(future, isAt: 25))

        let past = slots.slot(containing: at(-9))
        #expect(past.readingIndex == nil)
        #expect(slot(past, isAt: -10))
    }

    @Test("without readings every instant still resolves to a virtual mark")
    func noReadingsUsesVirtualGrid() {
        let slots = BGChartScrubSlots(readingDates: [])
        let mark = slots.slot(containing: at(7))
        #expect(mark.readingIndex == nil)
        #expect(mark.contains(at(7)))
        #expect(mark.blockEnd.timeIntervalSince(mark.blockStart) == 300)
    }

    @Test("blocks tile the timeline with no overlaps or holes")
    func blocksTileTimeline() {
        let slots = BGChartScrubSlots(readingDates: [0, 1, 2, 5, 7, 10, 33, 38, 43, 60].map(at))
        var previous: BGChartScrubSlots.Slot?

        for tenth in stride(from: -20.0, through: 80.0, by: 0.1) {
            let probe = at(tenth)
            let mark = slots.slot(containing: probe)
            #expect(mark.contains(probe), "\(tenth) min not inside its own block")
            if let previous, previous != mark {
                #expect(abs(mark.blockStart.timeIntervalSince(previous.blockEnd)) < 1e-6, "hole or overlap at \(tenth) min")
                #expect(previous.date < mark.date)
                let spacing = mark.date.timeIntervalSince(previous.date)
                #expect(spacing >= 150 && spacing <= 450, "mark spacing \(spacing) s at \(tenth) min")
            }
            previous = mark
        }
    }
}
