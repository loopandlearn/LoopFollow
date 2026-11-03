// LoopFollow
// TelemetrySendGateTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TelemetrySendGateTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60
    private let hour: TimeInterval = 60 * 60

    private func run(
        _ gate: TelemetrySendGate,
        lastSentAt: Date?,
        lastAttemptAt: Date? = nil,
        force: Bool = false,
        succeeds: Bool = true
    ) async -> (ran: Bool, result: Bool) {
        var ran = false
        let result = await gate.runIfEligible(
            now: now,
            lastSentAt: lastSentAt,
            lastAttemptAt: lastAttemptAt,
            minimumInterval: day,
            retryInterval: hour,
            force: force,
            operation: {
                ran = true
                return succeeds
            }
        )
        return (ran, result)
    }

    @Test("never sent is overdue")
    func neverSent() async {
        let outcome = await run(TelemetrySendGate(), lastSentAt: nil)
        #expect(outcome.ran)
        #expect(outcome.result)
    }

    @Test("a send within the daily interval is skipped")
    func withinInterval() async {
        let outcome = await run(TelemetrySendGate(), lastSentAt: now.addingTimeInterval(-day + 60))
        #expect(!outcome.ran)
    }

    @Test("a send after the daily interval runs")
    func afterInterval() async {
        let outcome = await run(TelemetrySendGate(), lastSentAt: now.addingTimeInterval(-day))
        #expect(outcome.ran)
    }

    @Test("force runs inside the daily interval")
    func forceInsideInterval() async {
        let outcome = await run(TelemetrySendGate(), lastSentAt: now.addingTimeInterval(-60), force: true)
        #expect(outcome.ran)
    }

    @Test("an attempt within the last hour blocks even a forced send")
    func retryBackoff() async {
        let outcome = await run(
            TelemetrySendGate(),
            lastSentAt: now.addingTimeInterval(-2 * day),
            lastAttemptAt: now.addingTimeInterval(-hour + 60),
            force: true
        )
        #expect(!outcome.ran)
    }

    @Test("an attempt over an hour ago allows a retry")
    func retryAfterBackoff() async {
        let outcome = await run(
            TelemetrySendGate(),
            lastSentAt: now.addingTimeInterval(-2 * day),
            lastAttemptAt: now.addingTimeInterval(-hour)
        )
        #expect(outcome.ran)
    }

    @Test("callbacks report attempt and success")
    func callbacks() async {
        let gate = TelemetrySendGate()
        var attempts = 0
        var successes = 0
        for succeeds in [false, true] {
            _ = await gate.runIfEligible(
                now: now,
                lastSentAt: nil,
                lastAttemptAt: nil,
                minimumInterval: day,
                retryInterval: hour,
                operation: { succeeds },
                onAttempt: { attempts += 1 },
                onSuccess: { successes += 1 }
            )
        }
        #expect(attempts == 2)
        #expect(successes == 1)
    }

    @Test("request URL carries reason and failure category")
    func requestURL() throws {
        let base = try #require(URL(string: "https://example.org/api/telemetry/"))
        let url = try #require(TelemetryClient.requestURL(
            baseURL: base,
            path: "anonymous",
            reason: .buildChange,
            lastFailureReason: "checkin_http_500"
        ))
        #expect(url.absoluteString == "https://example.org/api/telemetry/anonymous?reason=build_change&lastFailureReason=checkin_http_500")

        let plain = try #require(TelemetryClient.requestURL(baseURL: base, path: "checkin", reason: .timer, lastFailureReason: nil))
        #expect(plain.absoluteString == "https://example.org/api/telemetry/checkin?reason=timer")
    }
}
