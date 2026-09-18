// LoopFollow
// BGChartTapCandidateTests.swift

import CoreGraphics
@testable import LoopFollow
import Testing

struct BGChartTapCandidateTests {
    @Test("closest candidate wins regardless of collection order")
    func closestCandidateWins() {
        let candidates = [
            BGChartTapCandidate(value: "farther-first", distanceSquared: 20 * 20),
            BGChartTapCandidate(value: "closest", distanceSquared: 4 * 4),
            BGChartTapCandidate(value: "farther-last", distanceSquared: 12 * 12),
        ]

        #expect(nearestBGChartTapCandidate(candidates, within: 30) == "closest")
    }

    @Test("candidate exactly on the hit radius is included")
    func radiusIsInclusive() {
        let candidates = [
            BGChartTapCandidate(value: "edge", distanceSquared: 30 * 30),
        ]

        #expect(nearestBGChartTapCandidate(candidates, within: 30) == "edge")
    }

    @Test("candidates outside the hit radius are ignored")
    func outsideRadiusIsIgnored() {
        let candidates = [
            BGChartTapCandidate(value: "outside", distanceSquared: 30 * 30 + 0.01),
        ]

        #expect(nearestBGChartTapCandidate(candidates, within: 30) == nil)
        #expect(nearestBGChartTapCandidate([BGChartTapCandidate<String>](), within: 30) == nil)
    }

    @Test("equal-distance candidates preserve source ordering")
    func equalDistancePreservesOrder() {
        let candidates = [
            BGChartTapCandidate(value: "first", distanceSquared: 10 * 10),
            BGChartTapCandidate(value: "second", distanceSquared: 10 * 10),
        ]

        #expect(nearestBGChartTapCandidate(candidates, within: 30) == "first")
    }
}

struct BGChartLifecycleTests {
    @Test("foreground remount does not erase valid plot geometry")
    func zeroFrameIsIgnored() {
        let valid = CGRect(x: 34, y: 0, width: 589, height: 279)

        #expect(retainedBGChartPlotFrame(current: valid, incoming: .zero) == valid)
    }

    @Test("new valid plot geometry replaces the retained frame")
    func validFrameIsUpdated() {
        let old = CGRect(x: 34, y: 0, width: 589, height: 279)
        let resized = CGRect(x: 28, y: 0, width: 700, height: 320)

        #expect(retainedBGChartPlotFrame(current: old, incoming: resized) == resized)
    }
}
