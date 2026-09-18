// LoopFollow
// DeviceStatusMetricHistoryParserTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct DeviceStatusMetricHistoryParserTests {
    private let now = Date(timeIntervalSince1970: 1_786_450_200) // 2026-08-11 12:10:00Z

    @Test("Loop uses metric-native timestamps and preserves zero COB")
    func parsesLoopMetrics() throws {
        let payload = try entries(
            """
            [{
              "created_at": "2026-08-11T12:05:00.000Z",
              "loop": {
                "timestamp": "2026-08-11T12:04:30Z",
                "iob": {"iob": 1.25, "timestamp": "2026-08-11T12:00:00Z"},
                "cob": {"cob": 0, "timestamp": "2026-08-11T12:01:00Z"}
              }
            }]
            """
        )

        let samples = DeviceStatusMetricHistoryParser.samples(from: payload, now: now)

        #expect(samples.count == 2)
        #expect(samples[0].date == date("2026-08-11T12:00:00Z"))
        #expect(samples[0].iob == 1.25)
        #expect(samples[0].cob == nil)
        #expect(samples[1].date == date("2026-08-11T12:01:00Z"))
        #expect(samples[1].cob == 0)
    }

    @Test("Trio determination values win over the legacy IOB object")
    func parsesTrioDetermination() throws {
        let payload = try entries(
            """
            [{
              "created_at": "2026-08-11T12:06:00Z",
              "openaps": {
                "iob": {"iob": 1.3, "time": "2026-08-11T12:04:00Z"},
                "suggested": {
                  "IOB": 1.4,
                  "COB": 34,
                  "deliverAt": "2026-08-11T12:05:00Z"
                }
              }
            }]
            """
        )

        let samples = DeviceStatusMetricHistoryParser.samples(from: payload, now: now)

        #expect(samples == [
            DeviceStatusMetricSample(
                date: date("2026-08-11T12:05:00Z"),
                iob: 1.4,
                cob: 34
            ),
        ])
    }

    @Test("Trio falls back independently from suggested to enacted")
    func fallsBackToEnacted() throws {
        let payload = try entries(
            """
            [{
              "created_at": "2026-08-11T12:06:00Z",
              "openaps": {
                "suggested": {"IOB": 2.0, "deliverAt": "2026-08-11T12:05:00Z"},
                "enacted": {"COB": 21, "timestamp": "2026-08-11T12:04:00Z"}
              }
            }]
            """
        )

        let samples = DeviceStatusMetricHistoryParser.samples(from: payload, now: now)

        #expect(samples.count == 2)
        #expect(samples[0].cob == 21)
        #expect(samples[1].iob == 2)
    }

    @Test("Legacy OpenAPS IOB arrays and reason-only decimal COB are supported")
    func parsesLegacyOpenAPS() throws {
        let payload = try entries(
            """
            [{
              "created_at": "2026-08-11T12:06:00Z",
              "openaps": {
                "iob": [
                  {"iob": 9, "time": "2026-08-11T12:01:00Z"},
                  {"iob": -0.25, "time": "2026-08-11T12:03:00Z"}
                ],
                "suggested": {
                  "reason": "COB: 18.5, Dev: 2",
                  "deliverAt": "2026-08-11T12:05:00Z"
                }
              }
            }]
            """
        )

        let samples = DeviceStatusMetricHistoryParser.samples(from: payload, now: now)

        #expect(samples.count == 2)
        #expect(samples[0].iob == -0.25)
        #expect(samples[1].cob == 18.5)
    }

    @Test("Newest upload wins when determinations carry the same timestamp")
    func deduplicatesCarriedForwardDeterminations() throws {
        let payload = try entries(
            """
            [
              {
                "created_at": "2026-08-11T12:10:00Z",
                "openaps": {"suggested": {"COB": 30, "deliverAt": "2026-08-11T12:05:00Z"}}
              },
              {
                "created_at": "2026-08-11T12:06:00Z",
                "openaps": {"suggested": {"COB": 29, "deliverAt": "2026-08-11T12:05:00Z"}}
              }
            ]
            """
        )

        let samples = DeviceStatusMetricHistoryParser.samples(from: payload, now: now)

        #expect(samples.count == 1)
        #expect(samples[0].cob == 30)
    }

    @Test("Determinations without their own timestamp do not become fresh history")
    func ignoresUntimestampedDeterminations() throws {
        let payload = try entries(
            """
            [{
              "created_at": "2026-08-11T12:09:00Z",
              "openaps": {"suggested": {"IOB": 1.2, "COB": 24}}
            }]
            """
        )

        #expect(DeviceStatusMetricHistoryParser.samples(from: payload, now: now).isEmpty)
    }

    @Test("JSON booleans are not treated as numeric on-board values")
    func ignoresBooleanMetrics() throws {
        let payload = try entries(
            """
            [{
              "created_at": "2026-08-11T12:09:00Z",
              "loop": {"iob": {"iob": true}, "cob": {"cob": false}}
            }]
            """
        )

        #expect(DeviceStatusMetricHistoryParser.samples(from: payload, now: now).isEmpty)
    }

    @Test("Offset ISO dates, millisecond dates, ordering, and cutoff filtering work")
    func parsesDatesAndFiltersRange() throws {
        let payload = try entries(
            """
            [
              {"date": 1786450320000, "loop": {"iob": {"iob": 3}}},
              {"created_at": "2026-08-11T08:00:00-04:00", "loop": {"cob": {"cob": 15}}},
              {"created_at": "2026-08-11T10:00:00Z", "loop": {"cob": {"cob": 10}}},
              {"created_at": "2026-08-11T12:25:00Z", "loop": {"iob": {"iob": 4}}},
              {"created_at": "invalid", "loop": {"iob": {"iob": 5}}}
            ]
            """
        )
        let cutoff = date("2026-08-11T11:00:00Z")

        let samples = DeviceStatusMetricHistoryParser.samples(
            from: payload,
            cutoff: cutoff,
            now: now
        )

        #expect(samples.count == 2)
        #expect(samples[0].date == date("2026-08-11T12:00:00Z"))
        #expect(samples[0].cob == 15)
        #expect(samples[1].date == date("2026-08-11T12:12:00Z"))
        #expect(samples[1].iob == 3)
    }

    private func entries(_ json: String) throws -> [[String: AnyObject]] {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [[String: AnyObject]])
    }

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }
}
