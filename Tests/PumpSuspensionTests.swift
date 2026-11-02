// LoopFollow
// PumpSuspensionTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct PumpSuspensionTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ minutes: Double) -> Date {
        t0.addingTimeInterval(minutes * 60)
    }

    private func note(_ text: String, _ minutes: Double) -> (date: Date, note: String) {
        (at(minutes), text)
    }

    private func dot(_ rate: Double, _ minutes: Double) -> MainViewController.basalGraphStruct {
        .init(basalRate: rate, date: at(minutes).timeIntervalSince1970)
    }

    /// The rate the chart draws at a time: each point holds until the next one.
    private func rate(at minutes: Double, in basal: [MainViewController.basalGraphStruct]) -> Double? {
        let time = at(minutes).timeIntervalSince1970
        return basal.sorted { $0.date < $1.date }.last { $0.date <= time }?.basalRate
    }

    // MARK: - Intervals

    @Test("A suspend pairs with the next resume")
    func pairsSuspendAndResume() {
        let intervals = PumpSuspension.intervals(
            notes: [note("PumpSuspend", 10), note("Pizza", 15), note("PumpResume", 40)],
            tempBasalStarts: [at(0), at(45)]
        )
        #expect(intervals == [DateInterval(start: at(10), end: at(40))])
    }

    @Test("A suspend without a resume ends at the next temp basal")
    func endsAtNextTempBasal() {
        let intervals = PumpSuspension.intervals(
            notes: [note("PumpSuspend", 10)],
            tempBasalStarts: [at(0), at(30)]
        )
        #expect(intervals == [DateInterval(start: at(10), end: at(30))])
    }

    @Test("A suspend without a resume or a later temp basal is ongoing")
    func ongoingSuspend() {
        let intervals = PumpSuspension.intervals(notes: [note("PumpSuspend", 10)], tempBasalStarts: [at(0)])
        #expect(intervals == [DateInterval(start: at(10), end: .distantFuture)])
    }

    @Test("A repeated suspend keeps the first start")
    func repeatedSuspend() {
        let intervals = PumpSuspension.intervals(
            notes: [note("PumpSuspend", 10), note("PumpSuspend", 20), note("PumpResume", 40)],
            tempBasalStarts: []
        )
        #expect(intervals == [DateInterval(start: at(10), end: at(40))])
    }

    @Test("A suspend ended by a temp basal is separate from a later suspend")
    func suspendAfterTempBasal() {
        let intervals = PumpSuspension.intervals(
            notes: [note("PumpSuspend", 10), note("PumpSuspend", 50), note("PumpResume", 60)],
            tempBasalStarts: [at(30)]
        )
        #expect(intervals == [DateInterval(start: at(10), end: at(30)), DateInterval(start: at(50), end: at(60))])
    }

    @Test("A resume without a suspend is ignored")
    func resumeWithoutSuspend() {
        let intervals = PumpSuspension.intervals(notes: [note("PumpResume", 10)], tempBasalStarts: [])
        #expect(intervals.isEmpty)
    }

    // MARK: - Basal steps

    @Test("Basal inside a suspension is drawn as 0")
    func zeroInsideSuspension() {
        let basal = [dot(1.2, 0), dot(1.2, 30), dot(0.8, 30), dot(0.8, 60)]
        let result = PumpSuspension.applying([DateInterval(start: at(20), end: at(40))], to: basal)
        #expect(rate(at: 10, in: result) == 1.2)
        #expect(rate(at: 25, in: result) == 0)
        #expect(rate(at: 35, in: result) == 0)
        #expect(rate(at: 50, in: result) == 0.8)
        #expect(result.map(\.date).max() == at(60).timeIntervalSince1970)
    }

    @Test("An ongoing suspension holds 0 to the end of the basal")
    func ongoingSuspensionToEnd() {
        let basal = [dot(1.0, 0), dot(1.0, 60)]
        let result = PumpSuspension.applying([DateInterval(start: at(30), end: .distantFuture)], to: basal)
        #expect(rate(at: 15, in: result) == 1.0)
        #expect(rate(at: 45, in: result) == 0)
        #expect(result.map(\.date).max() == at(60).timeIntervalSince1970)
    }

    @Test("Basal without suspensions is unchanged")
    func noSuspensions() {
        let basal = [dot(1.0, 0), dot(1.0, 60)]
        let result = PumpSuspension.applying([], to: basal)
        #expect(result.map(\.date) == basal.map(\.date))
        #expect(result.map(\.basalRate) == basal.map(\.basalRate))
    }
}
