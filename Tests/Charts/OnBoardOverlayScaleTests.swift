// LoopFollow
// OnBoardOverlayScaleTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct OnBoardOverlayScaleTests {
    @Test("lane stays within the chart fraction and below the low-BG line")
    func laneCeiling() {
        #expect(BGChartModel.onBoardLaneCeiling(maxBG: 250, lowLine: 70) == 55)
        #expect(BGChartModel.onBoardLaneCeiling(maxBG: 400, lowLine: 70) == 63)
    }

    @Test("IOB and COB normalize independently into the same lane")
    func independentNormalization() {
        let lane = 55.0
        let iob = BGChartModel.scaledOnBoardValue(2, maximum: 4, laneCeiling: lane)
        let cob = BGChartModel.scaledOnBoardValue(50, maximum: 100, laneCeiling: lane)

        #expect(iob == 27.5)
        #expect(cob == 27.5)
        #expect(BGChartModel.scaledOnBoardValue(4, maximum: 4, laneCeiling: lane) == lane)
        #expect(BGChartModel.scaledOnBoardValue(150, maximum: 100, laneCeiling: lane) == lane)
    }

    @Test("negative and invalid values stay on the zero baseline")
    func clampsToBaseline() {
        #expect(BGChartModel.scaledOnBoardValue(-0.5, maximum: 4, laneCeiling: 55) == 0)
        #expect(BGChartModel.scaledOnBoardValue(2, maximum: 0, laneCeiling: 55) == 0)
        #expect(BGChartModel.scaledOnBoardValue(.infinity, maximum: 4, laneCeiling: 55) == 0)
    }

    @Test("all-zero histories retain a finite normalization denominator")
    func zeroHistoryMaximum() {
        let points = [
            point(at: 0, value: 0),
            point(at: 300, value: -0.25),
        ]

        #expect(BGChartModel.onBoardMaximum(for: points) == 1)
    }

    @Test("runs split only when a device-status gap exceeds twelve minutes")
    func splitsRunsAtDataGaps() {
        let points = [
            point(at: 0, value: 1),
            point(at: 12 * 60, value: 0.8),
            point(at: 24 * 60 + 1, value: 0.5),
        ]

        let runs = BGChartModel.makeOnBoardRuns(points)

        #expect(runs.count == 2)
        #expect(runs[0].points.count == 2)
        #expect(runs[1].points == [points[2]])
    }

    @Test("nearest lookup is logarithmic and respects its tolerance")
    func nearestLookup() {
        let points = [
            point(at: 0, value: 1),
            point(at: 300, value: 0.8),
            point(at: 600, value: 0.5),
        ]

        #expect(BGChartModel.nearestOnBoardPoint(
            in: points,
            to: Date(timeIntervalSince1970: 460),
            tolerance: 180
        ) == points[2])
        #expect(BGChartModel.nearestOnBoardPoint(
            in: points,
            to: Date(timeIntervalSince1970: 1200),
            tolerance: 180
        ) == nil)
    }

    private func point(at timestamp: TimeInterval, value: Double) -> BGChartModel.OnBoardPoint {
        BGChartModel.OnBoardPoint(
            date: Date(timeIntervalSince1970: timestamp),
            value: value
        )
    }
}
