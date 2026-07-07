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
}
