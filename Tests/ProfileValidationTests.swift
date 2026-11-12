// LoopFollow
// ProfileValidationTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct ProfileValidationTests {
    private let existing = ["Default", "Sport", "School"]

    private func values(
        units: String = "mg/dL",
        basal: [(Int, Double)] = [(0, 0.85), (21600, 1.0)],
        carbRatio: [(Int, Double)] = [(0, 10)],
        sens: [(Int, Double)] = [(0, 50)],
        target: [(Int, Double, Double)] = [(0, 100, 110)]
    ) -> TherapyProfileValues {
        TherapyProfileValues(
            units: units,
            basal: basal.map { ProfileScheduleItem(seconds: $0.0, value: $0.1) },
            carbRatio: carbRatio.map { ProfileScheduleItem(seconds: $0.0, value: $0.1) },
            sensitivity: sens.map { ProfileScheduleItem(seconds: $0.0, value: $0.1) },
            target: target.map { ProfileRangeItem(seconds: $0.0, low: $0.1, high: $0.2) }
        )
    }

    @Test("names are trimmed and follow the contract rules")
    func names() {
        #expect(ProfileValidation.nameProblem("  Weekend ", existingNames: existing) == nil)
        #expect(ProfileValidation.normalizedName("  Weekend ") == "Weekend")
        #expect(ProfileValidation.nameProblem("   ", existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem(String(repeating: "a", count: 32), existingNames: existing) == nil)
        #expect(ProfileValidation.nameProblem(String(repeating: "a", count: 33), existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("Sick.Day", existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("$set", existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("Pay$", existingNames: existing) == nil)
        #expect(ProfileValidation.nameProblem("default", existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("sport", existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("SPORT", existingNames: existing, originalName: "Sport") == nil)
        #expect(ProfileValidation.nameProblem("School", existingNames: existing, originalName: "Sport") != nil)
        #expect(ProfileValidation.nameProblem("Sick day 🤒", existingNames: existing) == nil)
        #expect(ProfileValidation.nameProblem(String(repeating: "👨‍👩‍👧‍👦", count: 32), existingNames: existing) == nil)
        #expect(ProfileValidation.nameProblem(String(repeating: "👨‍👩‍👧‍👦", count: 33), existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("DEFAULT", existingNames: existing) != nil)
        #expect(ProfileValidation.nameProblem("Cafe\u{301}", existingNames: ["Caf\u{E9}"]) != nil)
        #expect(ProfileValidation.countProblem(profileCount: 19) == nil)
        #expect(ProfileValidation.countProblem(profileCount: 20) != nil)
    }

    @Test("values inside the limits pass")
    func valid() throws {
        let limits = try ProfileEditLimitsTests.limits(ProfileEditLimitsTests.contractLimitsJSON.replacingOccurrences(of: "\"basalRates\": [0, 0.05, 0.1, 0.15, 3.0, 3.05]", with: "\"basalRates\": [0.05, 0.85, 1.0]"))
        #expect(ProfileValidation.problems(values(), limits: limits).isEmpty)
    }

    @Test("schedule shape is checked")
    func scheduleShape() throws {
        let limits = try ProfileEditLimitsTests.limits()
        #expect(!ProfileValidation.scheduleProblems([], kind: .basal, limits: limits).isEmpty)
        #expect(!ProfileValidation.scheduleProblems([1800], kind: .basal, limits: limits).isEmpty)
        #expect(!ProfileValidation.scheduleProblems([0, 3600, 3600], kind: .basal, limits: limits).isEmpty)
        #expect(!ProfileValidation.scheduleProblems([0, 7200, 3600], kind: .basal, limits: limits).isEmpty)
        #expect(!ProfileValidation.scheduleProblems([0, 900], kind: .basal, limits: limits).isEmpty)
        #expect(!ProfileValidation.scheduleProblems([0, 86400], kind: .basal, limits: limits).isEmpty)
        #expect(ProfileValidation.scheduleProblems(Array(stride(from: 0, to: 86400, by: 1800)), kind: .basal, limits: limits).isEmpty)
        let twelve = try ProfileEditLimitsTests.limits(ProfileEditLimitsTests.contractLimitsJSON.replacingOccurrences(of: "\"maxSegments\": 48", with: "\"maxSegments\": 12"))
        #expect(!ProfileValidation.scheduleProblems(Array(stride(from: 0, to: 13 * 1800, by: 1800)), kind: .carbRatio, limits: twelve).isEmpty)
    }

    @Test("out-of-bounds values, unsupported basal rates, inverted ranges and unit mismatches are rejected")
    func bounds() throws {
        let limits = try ProfileEditLimitsTests.limits()
        let base = (basal: [(0, 0.1)], carb: [(0, 10.0)], sens: [(0, 50.0)], target: [(0, 100.0, 110.0)])
        #expect(ProfileValidation.problems(values(basal: base.basal), limits: limits).isEmpty)
        #expect(ProfileValidation.problems(values(basal: [(0, 0.12)]), limits: limits).count == 1)
        #expect(ProfileValidation.problems(values(basal: [(0, 3.05)]), limits: limits).count == 1)
        #expect(ProfileValidation.problems(values(basal: base.basal, carbRatio: [(0, 151)]), limits: limits).count == 1)
        #expect(ProfileValidation.problems(values(basal: base.basal, sens: [(0, 9)]), limits: limits).count == 1)
        #expect(ProfileValidation.problems(values(basal: base.basal, target: [(0, 86, 110)]), limits: limits).count == 1)
        #expect(ProfileValidation.problems(values(basal: base.basal, target: [(0, 120, 110)]), limits: limits).count == 1)
        #expect(ProfileValidation.problems(values(units: "mmol/L", basal: base.basal), limits: limits).count == 1)
        // Outside the recommended range is a warning, not a problem.
        #expect(ProfileValidation.problems(values(basal: base.basal, carbRatio: [(0, 3)], target: [(0, 90, 120)]), limits: limits).isEmpty)
    }

    @Test("basal schedules stay within the pump's entry limit")
    func basalSegmentLimit() throws {
        let limits = try ProfileEditLimitsTests.limits(ProfileEditLimitsTests.contractLimitsJSON.replacingOccurrences(of: "\"maxSegments\": 48", with: "\"maxSegments\": 48, \"maxBasalSegments\": 24"))
        let starts25 = Array(stride(from: 0, to: 25 * 1800, by: 1800))
        #expect(ProfileValidation.scheduleProblems(starts25, kind: .basal, limits: limits) == ["Basal Rates: at most 24 times are allowed."])
        #expect(ProfileValidation.scheduleProblems(Array(starts25.dropLast()), kind: .basal, limits: limits).isEmpty)
        #expect(ProfileValidation.scheduleProblems(starts25, kind: .carbRatio, limits: limits).isEmpty)
        let basal = starts25.map { ($0, 0.1) }
        #expect(ProfileValidation.problems(values(basal: basal), limits: limits).count == 1)
    }

    @Test("a pure rename is not checked against today's limits, a changed save is")
    func renameSkipsValueChecks() throws {
        let limits = try ProfileEditLimitsTests.limits()
        let json = """
        {"timezone": "UTC", "units": "mg/dL",
         "basal": [{"time": "00:00", "value": 0.12, "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": 80, "timeAsSeconds": 0}],
         "target_high": [{"time": "00:00", "value": 110, "timeAsSeconds": 0}]}
        """
        let store = try JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8))
        let stored = TherapyProfile(name: "Old Sport", store: store)
        #expect(ProfileValidation.problems(stored.values, limits: limits).count == 2)
        #expect(ProfileValidation.problems(for: .save(name: "Sport", original: stored, values: stored.values), limits: limits).isEmpty)

        var draft = ProfileDraft(stored.values)
        draft.carbRatio[0].value = 12
        #expect(ProfileValidation.problems(for: .save(name: "Old Sport", original: stored, values: draft.values), limits: limits).count == 2)
        #expect(ProfileValidation.problems(for: .save(name: "Copy", original: nil, values: stored.values), limits: limits).count == 2)
        #expect(ProfileValidation.problems(for: .activate(stored), limits: limits).isEmpty)
    }

    @Test("new segments go one step after the last, or into the first free slot")
    func addSegments() {
        var segments = [EditableSegment(seconds: 0, value: 1), EditableSegment(seconds: 21600, value: 2)]
        #expect(ProfileSegmentGrid.newSegmentStart(segments, segmentSeconds: 1800, maxSegments: 48) == 23400)
        segments = ProfileSegmentGrid.addSegment(to: segments, segmentSeconds: 1800, maxSegments: 48)
        #expect(segments.map(\.seconds) == [0, 21600, 23400])
        #expect(segments.last?.value == 2)
        let late = [EditableSegment(seconds: 0, value: 1), EditableSegment(seconds: 84600, value: 2)]
        #expect(ProfileSegmentGrid.newSegmentStart(late, segmentSeconds: 1800, maxSegments: 48) == 1800)
        let added = ProfileSegmentGrid.addSegment(to: late, segmentSeconds: 1800, maxSegments: 48)
        #expect(added.map(\.seconds) == [0, 1800, 84600])
        #expect(added[1].value == 1)
        #expect(ProfileSegmentGrid.newSegmentStart(late, segmentSeconds: 1800, maxSegments: 2) == nil)
        let full = stride(from: 0, to: 86400, by: 1800).map { EditableSegment(seconds: $0, value: 1) }
        #expect(ProfileSegmentGrid.newSegmentStart(full, segmentSeconds: 1800, maxSegments: 100) == nil)
    }

    @Test("a segment moves only between its neighbours, the first stays at midnight")
    func allowedStarts() {
        let segments = [EditableSegment(seconds: 0, value: 1), EditableSegment(seconds: 7200, value: 2), EditableSegment(seconds: 14400, value: 3)]
        #expect(ProfileSegmentGrid.allowedStarts(for: 0, in: segments, segmentSeconds: 1800) == [0])
        #expect(ProfileSegmentGrid.allowedStarts(for: 1, in: segments, segmentSeconds: 1800) == [1800, 3600, 5400, 7200, 9000, 10800, 12600])
        #expect(ProfileSegmentGrid.allowedStarts(for: 2, in: segments, segmentSeconds: 1800).last == 84600)
    }

    @Test("a draft round-trips its values and the diff shows effective values at each change")
    func draftAndDiff() {
        let original = values(basal: [(0, 0.85), (21600, 1.0)])
        var draft = ProfileDraft(original)
        #expect(draft.values == original)
        draft.basal[1].value = 1.2
        draft.basal.append(EditableSegment(seconds: 43200, value: 1.0))
        let rows = ProfileDiff.rows(old: ProfileDraft(original).basal, new: draft.basal) { String($0.value) }
        #expect(rows == [
            ProfileDiffRow(seconds: 0, old: "0.85", new: "0.85"),
            ProfileDiffRow(seconds: 21600, old: "1.0", new: "1.2"),
            ProfileDiffRow(seconds: 43200, old: "1.0", new: "1.0"),
        ])
        #expect(rows.filter(\.changed).map(\.seconds) == [21600])
    }
}
