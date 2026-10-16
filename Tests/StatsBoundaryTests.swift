// LoopFollow
// StatsBoundaryTests.swift

import Foundation
@testable import LoopFollow
import Testing

/// TIR and GRI use inclusive bands (70-180 is in range), compared at the display
/// precision of the current unit.
@Suite(.serialized)
struct StatsBoundaryTests {
    private func withUnit(_ unit: GlucoseDisplayUnit, _ body: () -> Void) {
        let previous = Storage.shared.units.value
        Storage.shared.units.value = unit.rawValue
        defer { Storage.shared.units.value = previous }
        body()
    }

    private let readings: [Double] = [53, 54, 69, 70, 71, 180, 181, 182, 250, 251]

    private func tir() -> (veryLow: Double, low: Double, inRange: Double, high: Double, veryHigh: Double) {
        TIRCalculator.calculatePercentages(
            readings: readings,
            veryLowThreshold: 54,
            lowThreshold: 70,
            highThreshold: 180,
            veryHighThreshold: 250
        )
    }

    @Test("TIR mg/dL: 70 and 180 are in range, 54 and 250 are not extreme")
    func tirMgdl() {
        withUnit(.mgdL) {
            let p = tir()
            #expect(p.veryLow == 10) // 53
            #expect(p.low == 20) // 54, 69
            #expect(p.inRange == 30) // 70, 71, 180
            #expect(p.high == 30) // 181, 182, 250
            #expect(p.veryHigh == 10) // 251
        }
    }

    @Test("TIR mmol/L: readings that display the same value share a band")
    func tirMmol() {
        withUnit(.mmolL) {
            let p = tir()
            #expect(p.veryLow == 10) // 53 -> 2.9
            #expect(p.low == 20) // 54 -> 3.0, 69 -> 3.8
            #expect(p.inRange == 40) // 70, 71 -> 3.9; 180, 181 -> 10.0
            #expect(p.high == 30) // 182 -> 10.1; 250, 251 -> 13.9
            #expect(p.veryHigh == 0)
        }
    }

    @Test("GRI: on-a-line readings are not counted as low or high; display precision applies")
    func gri() {
        let data = [71, 181].map { ShareGlucoseData(sgv: $0, date: 0, direction: nil) }

        withUnit(.mgdL) {
            let result = GRICalculator.calculate(bgData: data)
            #expect(result.hypoComponent == 0)
            #expect(result.hyperComponent == 25) // 181 is above 180: 0.5 x 50%
        }
        withUnit(.mmolL) {
            let result = GRICalculator.calculate(bgData: data)
            #expect(result.hypoComponent == 0)
            #expect(result.hyperComponent == 0) // 181 displays 10.0
        }
    }
}
