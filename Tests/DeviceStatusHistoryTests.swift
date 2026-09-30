// LoopFollow
// DeviceStatusHistoryTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct DeviceStatusHistoryParserTests {
    private func json(_ text: String) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    }

    @Test("Loop record yields IOB, COB and the forecast from its start date")
    func loopRecord() throws {
        let record = json("""
        {"created_at": "2026-09-27T10:00:30.000Z",
         "loop": {"timestamp": "2026-09-27T10:00:05Z",
                  "iob": {"iob": 1.25, "timestamp": "2026-09-27T10:00:00Z"},
                  "cob": {"cob": 20},
                  "predicted": {"startDate": "2026-09-27T09:59:00Z", "values": [110.4, 112.6, 115]}}}
        """)
        let (sample, createdAt) = try #require(DeviceStatusHistoryParser.parse(record))
        #expect(sample.eventualBG == 115)
        #expect(sample.date == DeviceStatusHistoryParser.parseDate("2026-09-27T10:00:05Z")!.timeIntervalSince1970)
        #expect(createdAt == DeviceStatusHistoryParser.parseDate("2026-09-27T10:00:30.000Z"))
        #expect(sample.iob == 1.25)
        #expect(sample.cob == 20)
        #expect(sample.smoothedBG == nil)
        #expect(sample.forecast?.curves["main"] == [110, 113, 115])
        #expect(sample.forecast?.start == DeviceStatusHistoryParser.parseDate("2026-09-27T09:59:00Z")!.timeIntervalSince1970)
    }

    @Test("Trio record yields smoothed BG, ISF, ratio and the four forecast curves")
    func trioRecord() throws {
        let record = json("""
        {"created_at": "2026-09-27T10:00:30.000Z", "device": "Trio",
         "pump": {"reservoir": 120.5, "battery": {"percent": 80}}, "uploader": {"battery": 55},
         "openaps": {"iob": {"iob": 2.5, "time": "2026-09-27T10:00:00Z"},
                     "suggested": {"deliverAt": "2026-09-27T10:00:10.123Z", "bg": 142, "COB": 12.5,
                                   "ISF": 45.2, "sensitivityRatio": 1.15, "eventualBG": 130,
                                   "current_target": 5.5, "CR": 9, "TDD": 42.1,
                                   "predBGs": {"IOB": [142, 140], "ZT": [142, 138], "UAM": [142, 145]}}}}
        """)
        let (sample, _) = try #require(DeviceStatusHistoryParser.parse(record))
        #expect(sample.date == DeviceStatusHistoryParser.parseDate("2026-09-27T10:00:10.123Z")!.timeIntervalSince1970)
        #expect(sample.iob == 2.5)
        #expect(sample.cob == 12.5)
        #expect(sample.smoothedBG == 142)
        #expect(sample.isf == 45.2)
        #expect(sample.sensitivityRatio == 1.15)
        #expect(sample.forecast?.curves.keys.sorted() == ["IOB", "UAM", "ZT"])
        #expect(sample.forecast?.start == sample.date)
        #expect(sample.eventualBG == 130)
        #expect(abs((sample.target ?? 0) - 99.09) < 0.1)
        #expect(sample.carbRatio == 9)
        #expect(sample.tdd == 42.1)
        #expect(sample.reservoir == 120.5)
        #expect(sample.pumpBattery == 80)
        #expect(sample.uploaderBattery == 55)
    }

    @Test("Loop's active override is kept")
    func loopOverride() throws {
        let record = json("""
        {"created_at": "2026-09-27T10:00:30Z",
         "override": {"active": true, "multiplier": 1.5, "currentCorrectionRange": {"minValue": 90, "maxValue": 100}},
         "loop": {"timestamp": "2026-09-27T10:00:05Z", "recommendedBolus": 0.4}}
        """)
        let (sample, _) = try #require(DeviceStatusHistoryParser.parse(record))
        #expect(sample.loopOverride == .init(multiplier: 1.5, minTarget: 90, maxTarget: 100))
        #expect(sample.recommendedBolus == 0.4)
    }

    @Test("A zero ISF is a placeholder, COB falls back to the reason string")
    func openAPSFallbacks() throws {
        let record = json("""
        {"created_at": "2026-09-27T10:00:30Z",
         "openaps": {"iob": [{"iob": 0.8}, {"iob": 0.6}],
                     "enacted": {"timestamp": "2026-09-27T10:00:00Z", "ISF": 0,
                                 "reason": "maxCOB: 120, COB: 7.5, Dev: 3, ISF: 54"}}}
        """)
        let (sample, _) = try #require(DeviceStatusHistoryParser.parse(record))
        #expect(sample.isf == nil)
        #expect(sample.cob == 7.5)
        #expect(sample.iob == 0.8)
    }

    @Test("Out-of-range forecast values are clamped")
    func hugeForecastValue() throws {
        let record = json("""
        {"created_at": "2026-09-27T10:00:30Z",
         "loop": {"timestamp": "2026-09-27T10:00:05Z", "predicted": {"values": [1e30, -5, 120]}}}
        """)
        let (sample, _) = try #require(DeviceStatusHistoryParser.parse(record))
        #expect(sample.forecast?.curves["main"] == [10000, 0, 120])
    }

    @Test("Uploader-only records carry nothing to graph")
    func uploaderOnly() {
        let record = json("""
        {"created_at": "2026-09-27T10:00:30Z", "uploader": {"battery": 80}}
        """)
        #expect(DeviceStatusHistoryParser.parse(record) == nil)
    }

    @Test("Offsets are honored")
    func offsetDates() {
        let utc = DeviceStatusHistoryParser.parseDate("2026-09-27T10:00:00Z")
        let offset = DeviceStatusHistoryParser.parseDate("2026-09-27T12:00:00+02:00")
        #expect(utc != nil)
        #expect(utc == offset)
    }
}

struct DeviceStatusHistoryStateTests {
    private let t0: TimeInterval = 1_800_000_000

    private func sample(_ minutes: Double, iob: Double = 1) -> DeviceStatusHistorySample {
        var s = DeviceStatusHistorySample(date: t0 + minutes * 60)
        s.iob = iob
        return s
    }

    @Test("An empty history fetches the whole window")
    func emptyPlan() {
        let state = DeviceStatusHistoryState()
        let ranges = state.missingRanges(windowStart: t0, latest: t0 + 3600, now: t0 + 3600)
        #expect(ranges == [.init(from: t0, to: t0 + 3600)])
    }

    @Test("The next record extends the history without a fetch")
    func appendNext() {
        var state = DeviceStatusHistoryState()
        state.markCovered(from: t0, to: t0 + 3600)
        let appended = state.appendLatest(sample(65), createdAt: t0 + 65 * 60)
        #expect(appended)
        #expect(state.coverageEnd == t0 + 65 * 60)
        #expect(state.missingRanges(windowStart: t0, latest: t0 + 65 * 60, now: t0 + 66 * 60).isEmpty)
    }

    @Test("A record after a gap is refused and only the gap is fetched")
    func gapFetch() {
        var state = DeviceStatusHistoryState()
        state.markCovered(from: t0, to: t0 + 3600)
        let appended = state.appendLatest(sample(120), createdAt: t0 + 120 * 60)
        #expect(!appended)
        let now = t0 + 121 * 60
        let ranges = state.missingRanges(windowStart: t0, latest: t0 + 120 * 60, now: now)
        #expect(ranges == [.init(from: t0 + 3600 - DeviceStatusHistoryState.overlap, to: now)])
    }

    @Test("A record stamped ahead of the phone clock is included in the gap fetch")
    func futureRecord() {
        var state = DeviceStatusHistoryState()
        state.markCovered(from: t0, to: t0 + 3600)
        let now = t0 + 3600 + 60
        let latest = now + 600
        let ranges = state.missingRanges(windowStart: t0, latest: latest, now: now)
        #expect(ranges == [.init(from: t0 + 3600 - DeviceStatusHistoryState.overlap, to: latest)])
    }

    @Test("A longer Show Days Back window fetches only the older span")
    func widenedWindow() {
        var state = DeviceStatusHistoryState()
        state.markCovered(from: t0, to: t0 + 3600)
        let ranges = state.missingRanges(windowStart: t0 - 86400, latest: t0 + 3600, now: t0 + 3600)
        #expect(ranges == [.init(from: t0 - 86400, to: t0 + DeviceStatusHistoryState.overlap)])
    }

    @Test("A cache that ended before the window refetches the window")
    func staleCache() {
        var state = DeviceStatusHistoryState()
        state.markCovered(from: t0, to: t0 + 3600)
        let windowStart = t0 + 2 * 86400
        let ranges = state.missingRanges(windowStart: windowStart, latest: windowStart + 86400, now: windowStart + 86400)
        #expect(ranges == [.init(from: windowStart, to: windowStart + 86400)])
    }

    @Test("Merging replaces same-second samples and keeps dates ascending")
    func mergeDedupes() {
        var state = DeviceStatusHistoryState()
        state.merge([sample(10), sample(0)])
        state.merge([sample(5), sample(10, iob: 3)])
        #expect(state.samples.map(\.date) == [t0, t0 + 300, t0 + 600])
        #expect(state.samples.last?.iob == 3)
    }

    @Test("Pruning drops old samples and shrinks coverage")
    func prune() {
        var state = DeviceStatusHistoryState()
        state.merge([sample(0), sample(5), sample(10)])
        state.markCovered(from: t0, to: t0 + 600)
        state.prune(before: t0 + 240)
        #expect(state.samples.count == 2)
        #expect(state.coverageStart == t0 + 240)
        state.prune(before: t0 + 3600)
        #expect(state.isEmpty)
    }

    @Test("The forecast of a reading comes from the first loop cycle after it")
    func cycleForReading() {
        var state = DeviceStatusHistoryState()
        state.merge([sample(0), sample(5), sample(10)])
        #expect(state.cycle(forReadingAt: t0 + 4 * 60)?.date == t0 + 300)
        #expect(state.cycle(forReadingAt: t0 + 5.5 * 60)?.date == t0 + 300)
        #expect(state.cycle(forReadingAt: t0 + 30 * 60) == nil)
    }

    @Test("Round-trips through JSON")
    func codable() throws {
        var state = DeviceStatusHistoryState()
        var s = sample(0)
        s.forecast = .init(start: t0, curves: ["main": [100, 105]])
        state.merge([s])
        state.markCovered(from: t0, to: t0 + 600)
        let decoded = try JSONDecoder().decode(DeviceStatusHistoryState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }
}

struct BGChartHistoryTests {
    private let t0: TimeInterval = 1_800_000_000

    private func samples(_ values: [(minutes: Double, iob: Double)]) -> [DeviceStatusHistorySample] {
        values.map {
            var s = DeviceStatusHistorySample(date: t0 + $0.minutes * 60)
            s.iob = $0.iob
            return s
        }
    }

    @Test("Lines break across gaps longer than fifteen minutes")
    func segments() {
        let points = BGChartHistory.points(from: samples([(0, 1), (5, 1), (30, 1), (35, 1)])) { $0.iob }
        #expect(points.map(\.segment) == [0, 0, 1, 1])
    }

    @Test("The IOB pane includes zero and negative values")
    func iobScale() throws {
        let pane = try #require(BGChartHistory.pane(kind: .iob, samples: samples([(0, -0.4), (5, 2.3)])))
        #expect(pane.ticks == [0, 3])
        #expect(pane.yDomain.lowerBound < -0.4)
        #expect(pane.yDomain.upperBound > 3)
    }

    @Test("Negative IOB splits into its own run at the zero crossing")
    func negativeIOBSplit() {
        let points = BGChartHistory.points(from: samples([(0, 1), (5, -1), (10, -2)])) { $0.iob }
        let (positive, negative) = BGChartHistory.splitAtZero(points)
        #expect(positive.map(\.value) == [1, 0])
        #expect(negative.map(\.value) == [0, -1, -2])
        let crossing = t0 + 150
        #expect(positive.last?.date.timeIntervalSince1970 == crossing)
        #expect(negative.first?.date.timeIntervalSince1970 == crossing)
        #expect(positive.last?.segment != negative.first?.segment)
    }

    @Test("An IOB of exactly zero joins both runs without duplicate points")
    func exactZeroSplit() {
        for values in [[1.0, 0, -1], [-1.0, 0, 1]] {
            let points = BGChartHistory.points(from: samples(values.enumerated().map { (Double($0.offset * 5), $0.element) })) { $0.iob }
            let (positive, negative) = BGChartHistory.splitAtZero(points)
            for run in [positive, negative] {
                let keys = run.map { "\($0.segment)-\($0.date.timeIntervalSince1970)" }
                #expect(Set(keys).count == keys.count)
            }
            #expect(negative.contains { $0.value == 0 })
            #expect(positive.contains { $0.value == 0 })
        }
    }

    @Test("The main-graph overlay mirrors negative IOB and names it in the legend")
    func overlayLegend() throws {
        let overlay = try #require(BGChartHistory.overlay(kinds: [.iob], samples: samples([(0, 2), (5, -1)]), bandTop: 60))
        #expect(overlay.series.map(\.isNegative) == [false, true])
        #expect(overlay.legend.count == 1)
        #expect(overlay.legend.first?.hasNegative == true)
        let maxDrawn = overlay.series.flatMap(\.points).map(\.value).max() ?? 0
        #expect(maxDrawn <= 60)
        #expect(overlay.series.flatMap(\.points).allSatisfy { $0.value >= 0 })
    }

    @Test("A pane without values is not shown")
    func emptyPane() {
        #expect(BGChartHistory.pane(kind: .cob, samples: samples([(0, 1)])) == nil)
    }
}
