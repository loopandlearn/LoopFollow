// LoopFollow
// NightscoutTreatmentDateTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct NightscoutTreatmentDateTests {
    private typealias Entry = [String: AnyObject]

    private let expected = Date(timeIntervalSince1970: 1_787_000_000)

    @Test("parses an ISO 8601 timestamp string")
    func parsesStringTimestamp() {
        let entry: Entry = ["timestamp": "2026-08-17T20:53:20.000Z" as AnyObject]
        #expect(NightscoutUtils.treatmentDate(from: entry) == expected)
    }

    @Test("falls back to created_at when timestamp is missing")
    func fallsBackToCreatedAt() {
        let entry: Entry = ["created_at": "2026-08-17T20:53:20Z" as AnyObject]
        #expect(NightscoutUtils.treatmentDate(from: entry) == expected)
    }

    @Test("falls back to created_at when timestamp is JSON null")
    func nullTimestampFallsBack() {
        let entry: Entry = [
            "timestamp": NSNull(),
            "created_at": "2026-08-17T20:53:20Z" as AnyObject,
        ]
        #expect(NightscoutUtils.treatmentDate(from: entry) == expected)
    }

    @Test("accepts epoch milliseconds and seconds")
    func parsesNumericTimestamp() {
        let millis: Entry = ["timestamp": NSNumber(value: 1_787_000_000_000)]
        let seconds: Entry = ["timestamp": NSNumber(value: 1_787_000_000)]
        #expect(NightscoutUtils.treatmentDate(from: millis) == expected)
        #expect(NightscoutUtils.treatmentDate(from: seconds) == expected)
    }

    @Test("returns nil instead of trapping on unsupported values")
    func unsupportedValuesReturnNil() {
        let bool: Entry = ["timestamp": NSNumber(value: true)]
        let array: Entry = ["timestamp": ["2026-08-17T20:53:20Z"] as AnyObject]
        let garbage: Entry = ["timestamp": "not a date" as AnyObject]
        let empty: Entry = [:]
        #expect(NightscoutUtils.treatmentDate(from: bool) == nil)
        #expect(NightscoutUtils.treatmentDate(from: array) == nil)
        #expect(NightscoutUtils.treatmentDate(from: garbage) == nil)
        #expect(NightscoutUtils.treatmentDate(from: empty) == nil)
    }
}
