// LoopFollow
// ProfileInsulinComparisonTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct ProfileInsulinComparisonTests {
    static func values(
        units: String = "mg/dL",
        basal: [(Int, Double)] = [(0, 0.8)],
        carbRatio: [(Int, Double)] = [(0, 10)],
        sensitivity: [(Int, Double)] = [(0, 50)],
        target: [(Int, Double, Double)] = [(0, 100, 110)]
    ) -> TherapyProfileValues {
        TherapyProfileValues(
            units: units,
            basal: basal.map { ProfileScheduleItem(seconds: $0.0, value: $0.1) },
            carbRatio: carbRatio.map { ProfileScheduleItem(seconds: $0.0, value: $0.1) },
            sensitivity: sensitivity.map { ProfileScheduleItem(seconds: $0.0, value: $0.1) },
            target: target.map { ProfileRangeItem(seconds: $0.0, low: $0.1, high: $0.2) }
        )
    }

    @Test("identical values give no increase")
    func identical() {
        #expect(ProfileInsulinComparison.increases(from: Self.values(), to: Self.values()).isEmpty)
    }

    @Test("less insulin everywhere gives no increase")
    func lessInsulin() {
        let new = Self.values(basal: [(0, 0.7)], carbRatio: [(0, 12)], sensitivity: [(0, 60)], target: [(0, 110, 120)])
        #expect(ProfileInsulinComparison.increases(from: Self.values(), to: new).isEmpty)
        #expect(ProfileInsulinComparison.basalTotalIncrease(from: Self.values(), to: new) == nil)
    }

    @Test("a higher basal segment is reported with its times and the day total")
    func higherBasalSegment() throws {
        let new = Self.values(basal: [(0, 0.8), (21600, 1.0), (32400, 0.8)])
        let increases = ProfileInsulinComparison.increases(from: Self.values(), to: new)
        #expect(increases == [ProfileInsulinIncrease(kind: .basal, periods: [21600 ... 32400])])
        let total = try #require(ProfileInsulinComparison.basalTotalIncrease(from: Self.values(), to: new))
        #expect(abs(total.old - 19.2) < 1e-9)
        #expect(abs(total.new - 19.8) < 1e-9)
    }

    @Test("lower carb ratio, sensitivity and target each count as more insulin")
    func lowerRatios() {
        let new = Self.values(carbRatio: [(0, 9)], sensitivity: [(0, 50), (43200, 45)], target: [(0, 100, 105)])
        let kinds = ProfileInsulinComparison.increases(from: Self.values(), to: new).map(\.kind)
        #expect(Set(kinds) == [.carbRatio, .sensitivity, .correctionRange])
        let sensitivity = ProfileInsulinComparison.increases(from: Self.values(), to: new).first { $0.kind == .sensitivity }
        #expect(sensitivity?.periods == [43200 ... 86400])
    }

    @Test("adjacent periods merge, and a whole day reads as all day")
    func mergeAndAllDay() throws {
        let old = Self.values(basal: [(0, 0.5), (3600, 0.6)])
        let new = Self.values(basal: [(0, 0.7), (3600, 0.8)])
        let increase = try #require(ProfileInsulinComparison.increases(from: old, to: new).first)
        #expect(increase.periods == [0 ... 86400])
        #expect(increase.text == "Basal Rates higher all day")
    }

    @Test("glucose values compare across units")
    func acrossUnits() {
        let old = Self.values(units: "mmol/L", sensitivity: [(0, 2.8)], target: [(0, 5.5, 6.1)])
        let sameInMgdl = Self.values(units: "mg/dL", sensitivity: [(0, 50.5)], target: [(0, 99.5, 110)])
        #expect(ProfileInsulinComparison.increases(from: old, to: sameInMgdl).isEmpty)
        let lower = Self.values(units: "mg/dL", sensitivity: [(0, 45)], target: [(0, 99.5, 110)])
        #expect(ProfileInsulinComparison.increases(from: old, to: lower).map(\.kind) == [.sensitivity])
    }
}
