// LoopFollow
// SmoothedBgHistoryTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct SmoothedBgHistoryTests {
    @Test("suggested smoothed BG and fractional deliverAt take priority")
    func suggestedTakesPriority() throws {
        let data = Data(
            """
            {
              "created_at": "2026-08-11T12:00:03.000Z",
              "openaps": {
                "suggested": {
                  "bg": 123.5,
                  "deliverAt": "2026-08-11T12:00:01.250Z"
                },
                "enacted": {
                  "bg": 111,
                  "timestamp": "2026-08-11T11:55:00Z"
                }
              }
            }
            """.utf8
        )

        let record = try JSONDecoder().decode(DeviceStatusBgRecord.self, from: data)
        let point = try #require(record.point())
        let expectedDate = try #require(SmoothedBgSeries.parseDate("2026-08-11T12:00:01.250Z"))

        #expect(point.bgMgdl == 123.5)
        #expect(point.time == expectedDate.timeIntervalSince1970)
    }

    @Test("sparse suggested block falls back to enacted BG")
    func enactedFallback() throws {
        let data = Data(
            """
            {
              "created_at": "2026-08-11T12:00:03Z",
              "openaps": {
                "suggested": { "reason": "no temp required" },
                "enacted": {
                  "bg": 109,
                  "timestamp": "2026-08-11T11:59:59Z"
                }
              }
            }
            """.utf8
        )

        let record = try JSONDecoder().decode(DeviceStatusBgRecord.self, from: data)
        let point = try #require(record.point())
        let expectedDate = try #require(SmoothedBgSeries.parseDate("2026-08-11T11:59:59Z"))

        #expect(point.bgMgdl == 109)
        #expect(point.time == expectedDate.timeIntervalSince1970)
    }

    @Test("ISO timestamps preserve explicit timezone offsets")
    func timezoneOffset() throws {
        let offsetPoint = try #require(SmoothedBgSeries.point(
            bg: 120,
            timestampCandidates: ["2026-08-11T14:00:01.250+02:00"]
        ))
        let utcPoint = try #require(SmoothedBgSeries.point(
            bg: 120,
            timestampCandidates: ["2026-08-11T12:00:01.250Z"]
        ))

        #expect(offsetPoint.time == utcPoint.time)
    }

    @Test("chart series filters treatment-triggered records closer than four minutes")
    func chartSpacing() {
        let points = [
            SmoothedBgPoint(time: 0, bgMgdl: 100),
            SmoothedBgPoint(time: 100, bgMgdl: 101),
            SmoothedBgPoint(time: 300, bgMgdl: 102),
            SmoothedBgPoint(time: 540, bgMgdl: 103),
            SmoothedBgPoint(time: 900, bgMgdl: 104),
        ]

        let filtered = SmoothedBgSeries.chartPoints(
            from: points,
            startingAt: 0,
            endingAt: 600
        )

        #expect(filtered.map(\.time) == [0, 300, 540])
    }

    @Test("nearest lookup observes its tolerance")
    func nearestTolerance() {
        let points = [
            SmoothedBgPoint(time: 100, bgMgdl: 101),
            SmoothedBgPoint(time: 300, bgMgdl: 103),
        ]

        #expect(SmoothedBgSeries.nearestValue(in: points, to: 240) == 103)
        #expect(SmoothedBgSeries.nearestValue(in: points, to: 500) == nil)
    }

    @Test("new info type preserves upstream DB Size raw value")
    func infoTypeRawValues() {
        #expect(InfoType.dbSize.rawValue == 20)
        #expect(InfoType.smoothedBg.rawValue == 21)
    }
}
