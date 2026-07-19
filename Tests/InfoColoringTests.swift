// LoopFollow
// InfoColoringTests.swift

@testable import LoopFollow
import SwiftUI
import Testing

struct InfoColoringTests {
    @Test("disabled coloring returns nil regardless of value")
    func disabledReturnsNil() {
        let coloring = InfoColoring(enabled: false, warning: 30, urgent: 15)
        #expect(coloring.color(for: 5, direction: .below) == nil)
    }

    @Test("below: battery warn 30 / urgent 15, in-range is green")
    func belowDirection() {
        let coloring = InfoColoring(enabled: true, warning: 30, urgent: 15)
        #expect(coloring.color(for: 40, direction: .below) == .green)
        #expect(coloring.color(for: 30, direction: .below) == .yellow)
        #expect(coloring.color(for: 25, direction: .below) == .yellow)
        #expect(coloring.color(for: 15, direction: .below) == .red)
        #expect(coloring.color(for: 10, direction: .below) == .red)
    }

    @Test("above: SAGE warn 8 / urgent 9.5, in-range is green")
    func aboveDirection() {
        let coloring = InfoColoring(enabled: true, warning: 8, urgent: 9.5)
        #expect(coloring.color(for: 6, direction: .above) == .green)
        #expect(coloring.color(for: 8, direction: .above) == .yellow)
        #expect(coloring.color(for: 8.5, direction: .above) == .yellow)
        #expect(coloring.color(for: 9.5, direction: .above) == .red)
        #expect(coloring.color(for: 12, direction: .above) == .red)
    }

    @Test("nil thresholds are green when enabled")
    func nilThresholds() {
        let coloring = InfoColoring(enabled: true, warning: nil, urgent: nil)
        #expect(coloring.color(for: 999, direction: .above) == .green)
    }

    @Test("only urgent set still colors red, otherwise green")
    func onlyUrgent() {
        let coloring = InfoColoring(enabled: true, warning: nil, urgent: 15)
        #expect(coloring.color(for: 20, direction: .below) == .green)
        #expect(coloring.color(for: 15, direction: .below) == .red)
    }

    @Test("pump reservoir colors on the way down, and a capped 50+ reads green")
    func pumpReservoir() throws {
        let config = try #require(InfoType.pump.colorConfig)
        let coloring = InfoColoring(enabled: true, warning: config.defaultWarning, urgent: config.defaultUrgent)
        #expect(coloring.color(for: 50, direction: config.direction) == .green)
        #expect(coloring.color(for: 20, direction: config.direction) == .yellow)
        #expect(coloring.color(for: 10, direction: config.direction) == .red)
    }

    @Test("thresholds that need decimals get a fractional step")
    func fractionalSteps() {
        #expect(InfoType.recBolus.colorConfig?.step == 0.1)
        #expect(InfoType.iob.colorConfig?.step == 0.5)
        #expect(InfoType.sage.colorConfig?.fractionDigits == 1)
        #expect(InfoType.cob.colorConfig?.fractionDigits == 0)
    }

    @Test("non-numeric rows are not colorable")
    func notColorable() {
        #expect(InfoType.basal.isColorable == false)
        #expect(InfoType.minMax.isColorable == false)
        #expect(InfoType.pump.isColorable)
    }
}
