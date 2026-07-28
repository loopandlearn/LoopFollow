// LoopFollow
// LowestForecastTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct LowestForecastTests {
    private let start: TimeInterval = 1_000_000

    // MARK: - Combining

    @Test("#takes the per-point minimum across forecasts")
    func perPointMinimum() {
        let forecasts: [[Double]] = [
            [150, 140, 130, 120],
            [120, 130, 100, 160],
            [130, 110, 140, 90],
        ]
        let result = MainViewController.lowestForecast(forecasts: forecasts, start: start)

        #expect(result.map(\.sgv) == [120, 110, 100, 90])
    }

    @Test("#empty forecasts are ignored")
    func emptyForecastsIgnored() {
        let forecasts: [[Double]] = [
            [],
            [120, 110, 100],
            [],
        ]
        let result = MainViewController.lowestForecast(forecasts: forecasts, start: start)

        #expect(result.map(\.sgv) == [120, 110, 100])
    }

    @Test("#all empty yields no points")
    func allEmpty() {
        let result = MainViewController.lowestForecast(forecasts: [[], []], start: start)
        #expect(result.isEmpty)
    }

    @Test("#no forecasts yields no points")
    func noForecasts() {
        let result = MainViewController.lowestForecast(forecasts: [], start: start)
        #expect(result.isEmpty)
    }

    @Test("#uneven lengths use whichever forecasts still extend")
    func unevenLengths() {
        let forecasts: [[Double]] = [
            [100, 90], // shorter
            [110, 95, 80, 70], // longer
        ]
        let result = MainViewController.lowestForecast(forecasts: forecasts, start: start)

        // Points 0-1 use the min of both; points 2-3 use only the longer forecast.
        #expect(result.map(\.sgv) == [100, 90, 80, 70])
    }

    // MARK: - Capping

    @Test("#caps the number of points")
    func capsPoints() {
        let long = Array(repeating: 100.0, count: 30)
        let result = MainViewController.lowestForecast(forecasts: [long], start: start, cap: 12)

        #expect(result.count == 12)
    }

    @Test("#the default cap reaches 60 minutes ahead")
    func defaultCap() {
        let long = Array(repeating: 100.0, count: 30)
        let result = MainViewController.lowestForecast(forecasts: [long], start: start)

        #expect(result.count == MainViewController.alarmForecastPointCap)
        // The first point is the current value, so the last one is 60 minutes out.
        #expect(result.last?.date.timeIntervalSince1970 == start + 3600)
    }

    @Test("#a short forecast does not cap the rest")
    func shortForecastDoesNotCapTheRest() {
        // Which forecast runs shortest varies from cycle to cycle, so the series
        // has to follow the longest one rather than the first to run out.
        let short = Array(repeating: 100.0, count: 8)
        let long = Array(repeating: 100.0, count: 20)
        let result = MainViewController.lowestForecast(forecasts: [short, long], start: start)

        #expect(result.count == MainViewController.alarmForecastPointCap)
    }

    // MARK: - Timestamps & rounding

    @Test("#points are spaced 5 minutes from start")
    func timestampSpacing() {
        let forecasts: [[Double]] = [[100, 100, 100]]
        let result = MainViewController.lowestForecast(forecasts: forecasts, start: start)

        #expect(result.map { $0.date.timeIntervalSince1970 } == [start, start + 300, start + 600])
    }

    @Test("#values are rounded to the nearest integer")
    func rounding() {
        let forecasts: [[Double]] = [[100.4, 100.6, 99.5]]
        let result = MainViewController.lowestForecast(forecasts: forecasts, start: start)

        #expect(result.map(\.sgv) == [100, 101, 100])
    }
}
