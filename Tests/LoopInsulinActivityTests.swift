// LoopFollow
// LoopInsulinActivityTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct LoopInsulinActivityTests {
    private typealias Basal = MainViewController.basalGraphStruct

    @Test("Activity is the rate at which insulin on board falls", arguments: LoopInsulinModel.allCases)
    func activityMatchesIOB(model: LoopInsulinModel) {
        let dt: TimeInterval = 10
        var acted = 0.0
        var time: TimeInterval = 0
        while time < model.effectDuration + 600 {
            acted += model.activity(at: time + dt / 2) * dt / 3600
            time += dt
            #expect(abs(acted - (1 - model.percentEffectRemaining(at: time))) < 1e-4)
        }
        #expect(abs(acted - 1) < 1e-4)
    }

    @Test("Activity starts after the delay and peaks at the model's peak")
    func activityShape() {
        let model = LoopInsulinModel.rapidActingAdult
        #expect(model.activity(at: 0) == 0)
        #expect(model.activity(at: model.delay) == 0)
        let peak = model.delay + model.peakActivity
        #expect(model.activity(at: peak) > model.activity(at: peak - 60))
        #expect(model.activity(at: peak) > model.activity(at: peak + 60))
        #expect(model.activity(at: model.effectDuration) == 0)
    }

    @Test("Temp basals count net of the scheduled rate, in five-minute doses")
    func netBasal() {
        // Scheduled 1 U/h, a 3 U/h temp basal for 10 minutes, then a 0 U/h
        // temp basal for 7 minutes.
        let scheduled = [Basal(basalRate: 1, date: 0), Basal(basalRate: 1, date: 7200)]
        let delivered = [
            Basal(basalRate: 3, date: 600), Basal(basalRate: 3, date: 1200),
            Basal(basalRate: 0, date: 1200), Basal(basalRate: 0, date: 1620),
            Basal(basalRate: 1, date: 1620),
        ]
        let doses = LoopInsulinActivity.netBasalDoses(delivered: delivered, scheduled: scheduled, until: 3600)
        let expected: [LoopInsulinActivity.Dose] = [
            .init(date: 600, units: 2.0 / 12),
            .init(date: 900, units: 2.0 / 12),
            .init(date: 1200, units: -1.0 / 12),
            .init(date: 1500, units: -1.0 * 120 / 3600),
        ]
        #expect(doses.count == expected.count)
        for (dose, want) in zip(doses, expected) {
            #expect(dose.date == want.date)
            #expect(abs(dose.units - want.units) < 1e-9)
        }
    }

    @Test("A scheduled rate change applies from its time on")
    func scheduleChange() {
        let scheduled = [Basal(basalRate: 1, date: 0), Basal(basalRate: 1, date: 900), Basal(basalRate: 2, date: 900), Basal(basalRate: 2, date: 7200)]
        let delivered = [Basal(basalRate: 2, date: 600), Basal(basalRate: 2, date: 1200)]
        let doses = LoopInsulinActivity.netBasalDoses(delivered: delivered, scheduled: scheduled, until: 3600)
        #expect(doses == [.init(date: 600, units: 1.0 / 12)])
    }

    @Test("An override's insulin needs scale the scheduled rate")
    func overrideScale() {
        let scheduled = [Basal(basalRate: 1, date: 0), Basal(basalRate: 1, date: 7200)]
        let delivered = [Basal(basalRate: 1, date: 0), Basal(basalRate: 1, date: 1200)]
        let overrides = [LoopInsulinActivity.Override(start: 600, end: 900, insulinNeedsScaleFactor: 1.5)]
        let doses = LoopInsulinActivity.netBasalDoses(delivered: delivered, scheduled: scheduled, overrides: overrides, until: 3600)
        #expect(doses.count == 1)
        #expect(doses.first?.date == 600)
        #expect(abs((doses.first?.units ?? 0) + 0.5 / 12) < 1e-9)
    }

    @Test("Activity sums the doses acting at each time")
    func activitySum() {
        let model = LoopInsulinModel.fiasp
        let doses: [LoopInsulinActivity.Dose] = [.init(date: 0, units: 2), .init(date: 1800, units: -0.5), .init(date: 99999, units: 5)]
        let times: [TimeInterval] = [0, 3600, model.effectDuration + 1800]
        let points = LoopInsulinActivity.activity(at: times, doses: doses, model: model)
        #expect(points.map(\.date) == times)
        #expect(points[0].value == 0)
        #expect(abs(points[1].value - (2 * model.activity(at: 3600) - 0.5 * model.activity(at: 1800))) < 1e-12)
        #expect(abs(points[2].value - (-0.5 * model.activity(at: model.effectDuration))) < 1e-12)
    }

    @Test("Times step every five minutes and end at the end time")
    func timeGrid() {
        #expect(LoopInsulinActivity.times(from: 100, to: 700) == [300, 600, 700])
        #expect(LoopInsulinActivity.times(from: 700, to: 100).isEmpty)
    }
}
