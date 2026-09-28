// LoopFollow
// DeviceStatusMetricBackfillTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct DeviceStatusMetricBackfillTests {
    private let now = Date(timeIntervalSince1970: 1_786_450_200) // 2026-08-11 12:10:00Z
    private let hour: TimeInterval = 3600

    @Test("Windows walk back in fixed chunks and clamp to the cutoff")
    func windowsClampToCutoff() throws {
        let cutoff = now.addingTimeInterval(-24 * hour)

        let first = try #require(DeviceStatusMetricBackfill.window(end: now, cutoff: cutoff))
        #expect(first.end == now)
        #expect(first.start == now.addingTimeInterval(-DeviceStatusMetricBackfill.chunkInterval))

        let nearCutoff = cutoff.addingTimeInterval(hour)
        let last = try #require(DeviceStatusMetricBackfill.window(end: nearCutoff, cutoff: cutoff))
        #expect(last.start == cutoff)
        #expect(last.end == nearCutoff)

        #expect(DeviceStatusMetricBackfill.window(end: cutoff, cutoff: cutoff) == nil)
        #expect(DeviceStatusMetricBackfill.window(end: cutoff.addingTimeInterval(-1), cutoff: cutoff) == nil)
    }

    @Test("A full day completes in a bounded number of windows")
    func fullDayWindowCount() {
        let cutoff = now.addingTimeInterval(-24 * hour)
        var end = now.addingTimeInterval(DeviceStatusMetricBackfill.futureAllowance)
        var windows = 0

        while let window = DeviceStatusMetricBackfill.window(end: end, cutoff: cutoff) {
            windows += 1
            end = DeviceStatusMetricBackfill.nextEnd(
                after: window,
                returnedCount: 10,
                requestedCount: 72,
                oldestReturned: window.start.addingTimeInterval(60)
            )
            #expect(windows < 100)
        }

        #expect(windows == 9)
    }

    @Test("Hitting the count cap pages within the same window")
    func pagesWhenCapped() throws {
        let window = try #require(
            DeviceStatusMetricBackfill.window(end: now, cutoff: now.addingTimeInterval(-24 * hour))
        )
        let oldest = now.addingTimeInterval(-hour)

        let capped = DeviceStatusMetricBackfill.nextEnd(
            after: window,
            returnedCount: 72,
            requestedCount: 72,
            oldestReturned: oldest
        )
        #expect(capped == oldest)

        let uncapped = DeviceStatusMetricBackfill.nextEnd(
            after: window,
            returnedCount: 71,
            requestedCount: 72,
            oldestReturned: oldest
        )
        #expect(uncapped == window.start)
    }

    @Test("Paging never stalls when the oldest record cannot advance")
    func pagingAlwaysProgresses() throws {
        let window = try #require(
            DeviceStatusMetricBackfill.window(end: now, cutoff: now.addingTimeInterval(-24 * hour))
        )

        for oldest in [window.end, window.end.addingTimeInterval(60), window.start, nil] {
            let next = DeviceStatusMetricBackfill.nextEnd(
                after: window,
                returnedCount: 72,
                requestedCount: 72,
                oldestReturned: oldest
            )
            #expect(next == window.start)
        }
    }

    @Test("Request count scales with uploader filtering")
    func requestCount() {
        #expect(DeviceStatusMetricBackfill.requestCount(uploaderFiltered: true) == 72)
        #expect(DeviceStatusMetricBackfill.requestCount(uploaderFiltered: false) == 144)
    }

    @Test("Retry delay backs off exponentially and caps")
    func retryDelay() {
        #expect(DeviceStatusMetricBackfill.retryDelay(afterFailures: 0) == 60)
        #expect(DeviceStatusMetricBackfill.retryDelay(afterFailures: 1) == 60)
        #expect(DeviceStatusMetricBackfill.retryDelay(afterFailures: 2) == 120)
        #expect(DeviceStatusMetricBackfill.retryDelay(afterFailures: 4) == 480)
        #expect(DeviceStatusMetricBackfill.retryDelay(afterFailures: 5) == 900)
        #expect(DeviceStatusMetricBackfill.retryDelay(afterFailures: 50) == 900)
    }

    @Test("Oldest record timestamp uses the upload time")
    func oldestRecordTimestamp() throws {
        let object = try JSONSerialization.jsonObject(with: Data(
            """
            [
              {"created_at": "2026-08-11T12:05:00.000Z"},
              {"created_at": "2026-08-11T11:05:00Z"},
              {"created_at": "invalid"}
            ]
            """.utf8
        ))
        let entries = try #require(object as? [[String: AnyObject]])

        let oldest = DeviceStatusMetricHistoryParser.oldestRecordTimestamp(in: entries)

        #expect(oldest == ISO8601DateFormatter().date(from: "2026-08-11T11:05:00Z"))
    }
}
