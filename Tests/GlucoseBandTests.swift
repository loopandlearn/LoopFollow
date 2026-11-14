// LoopFollow
// GlucoseBandTests.swift

@testable import LoopFollow
import Testing

struct GlucoseBandTests {
    @Test("mg/dL: a reading on a line is in range")
    func mgdlBoundaries() {
        #expect(GlucoseBand.of(69, low: 70, high: 180, mmol: false) == .low)
        #expect(GlucoseBand.of(70, low: 70, high: 180, mmol: false) == .inRange)
        #expect(GlucoseBand.of(71, low: 70, high: 180, mmol: false) == .inRange)
        #expect(GlucoseBand.of(180, low: 70, high: 180, mmol: false) == .inRange)
        #expect(GlucoseBand.of(181, low: 70, high: 180, mmol: false) == .high)
    }

    @Test("mg/dL: a line picked in mmol/L is compared as the whole number it displays")
    func mgdlFractionalLine() {
        // 3.9 mmol/L is stored as 70.26 (shared factor) or 70.2 (old x18 factor) and shows as 70.
        for low in [3.9 * GlucoseConversion.mmolToMgDl, 3.9 * 18] {
            #expect(GlucoseBand.of(69, low: low, high: 180, mmol: false) == .low)
            #expect(GlucoseBand.of(70, low: low, high: 180, mmol: false) == .inRange)
        }
        // 10.0 mmol/L is stored as 180.16 and shows as 180.
        let high = 10.0 * GlucoseConversion.mmolToMgDl
        #expect(GlucoseBand.of(180, low: 70, high: high, mmol: false) == .inRange)
        #expect(GlucoseBand.of(181, low: 70, high: high, mmol: false) == .high)
    }

    @Test("mmol/L: readings that display the same value get the same band")
    func mmolSameDisplayedValue() {
        // 70 and 71 mg/dL both display 3.9; 180 and 181 both display 10.0.
        #expect(GlucoseBand.of(69, low: 70, high: 180, mmol: true) == .low) // 3.8
        #expect(GlucoseBand.of(70, low: 70, high: 180, mmol: true) == .inRange)
        #expect(GlucoseBand.of(71, low: 70, high: 180, mmol: true) == .inRange)
        #expect(GlucoseBand.of(180, low: 70, high: 180, mmol: true) == .inRange)
        #expect(GlucoseBand.of(181, low: 70, high: 180, mmol: true) == .inRange)
        #expect(GlucoseBand.of(182, low: 70, high: 180, mmol: true) == .high) // 10.1
    }

    @Test("mmol/L: a line stored with the old x18 picker factor behaves like the picked value")
    func mmolLegacyPickerLine() {
        // 3.9 mmol/L picked with x18 is 70.2 mg/dL; 10.0 mmol/L is 180.0.
        #expect(GlucoseBand.of(69, low: 70.2, high: 180, mmol: true) == .low)
        #expect(GlucoseBand.of(70, low: 70.2, high: 180, mmol: true) == .inRange)
        #expect(GlucoseBand.of(71, low: 70.2, high: 180, mmol: true) == .inRange)
    }
}
