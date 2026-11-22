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

    @Test("a save of an existing profile is checked only in the schedules it changes")
    func saveChecksChangedSchedulesOnly() throws {
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
        #expect(ProfileValidation.problems(for: .save(name: "Old Sport", original: stored, values: draft.values), limits: limits).isEmpty)
        draft.carbRatio[0].value = 151
        #expect(ProfileValidation.problems(for: .save(name: "Old Sport", original: stored, values: draft.values), limits: limits).count == 1)
        draft.carbRatio[0].value = 12
        draft.basal[0].value = 0.15
        #expect(ProfileValidation.problems(for: .save(name: "Old Sport", original: stored, values: draft.values), limits: limits).isEmpty)
        draft.basal[0].value = 3.05
        #expect(ProfileValidation.problems(for: .save(name: "Old Sport", original: stored, values: draft.values), limits: limits).count == 1)
        #expect(ProfileValidation.problems(for: .save(name: "Copy", original: nil, values: stored.values), limits: limits).count == 2)
        #expect(ProfileValidation.problems(for: .activate(stored), limits: limits).isEmpty)
        #expect(ProfileValidation.activationProblems(stored, limits: limits).count == 2)
        #expect(ProfileValidation.activationProblems(stored, limits: nil).isEmpty)
        #expect(ProfileValidation.unchangedProblems(for: .save(name: "Old Sport", original: stored, values: draft.values), limits: limits).count == 1)
        #expect(ProfileValidation.unchangedProblems(for: .save(name: "Copy", original: nil, values: stored.values), limits: limits).isEmpty)
    }

    private func storedProfile(units: String = "mg/dL", basal: Double = 0.12, targetLow: Double = 80, targetHigh: Double = 110) throws -> TherapyProfile {
        let json = """
        {"timezone": "UTC", "units": "\(units)",
         "basal": [{"time": "00:00", "value": \(basal), "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": \(targetLow), "timeAsSeconds": 0}],
         "target_high": [{"time": "00:00", "value": \(targetHigh), "timeAsSeconds": 0}]}
        """
        return TherapyProfile(name: "Stored", store: try JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8)))
    }

    @Test("activation problems are left out for unusable limits, unit mismatches and profiles not read completely")
    func activationProblemsNeedComparableLimits() throws {
        let stored = try storedProfile()
        let limits = try ProfileEditLimitsTests.limits()
        #expect(ProfileValidation.activationProblems(stored, limits: limits).count == 2)
        let badGrid = try ProfileEditLimitsTests.limits(ProfileEditLimitsTests.contractLimitsJSON.replacingOccurrences(of: "\"segmentSeconds\": 1800", with: "\"segmentSeconds\": 1700"))
        let badStep = try ProfileEditLimitsTests.limits(ProfileEditLimitsTests.contractLimitsJSON.replacingOccurrences(of: "\"step\": 0.1", with: "\"step\": 0"))
        let zeroGrid = try ProfileEditLimitsTests.limits(ProfileEditLimitsTests.contractLimitsJSON.replacingOccurrences(of: "\"segmentSeconds\": 1800", with: "\"segmentSeconds\": 0"))
        #expect(ProfileValidation.activationProblems(stored, limits: badGrid).isEmpty)
        #expect(ProfileValidation.activationProblems(stored, limits: badStep).isEmpty)
        #expect(ProfileValidation.activationProblems(stored, limits: zeroGrid).isEmpty)
        #expect(!zeroGrid.isUsable)
        #expect(zeroGrid.segmentLimit == 0)
        #expect(!ProfileValidation.scheduleProblems([0], kind: .basal, limits: zeroGrid).isEmpty)
        let mmol = try storedProfile(units: "mmol/L", targetLow: 4.4, targetHigh: 6.1)
        #expect(ProfileValidation.activationProblems(mmol, limits: limits).isEmpty)
        let malformed = try JSONDecoder().decode(NSProfile.Store.self, from: Data("""
        {"timezone": "UTC", "units": "mg/dL",
         "basal": [{"time": "00:00", "value": 0.12, "timeAsSeconds": 0}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": 50, "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": 100, "timeAsSeconds": 0}, {"time": "06:00", "value": 100, "timeAsSeconds": 21600}],
         "target_high": [{"time": "00:00", "value": 110, "timeAsSeconds": 0}]}
        """.utf8))
        let notReadable = TherapyProfile(name: "Broken", store: malformed)
        #expect(!notReadable.isWellFormed)
        #expect(ProfileValidation.activationProblems(notReadable, limits: limits).isEmpty)
    }

    @Test("an unchanged out-of-limits Trio target is not checked while another schedule changes")
    func singleTargetUnchangedTarget() throws {
        let limits = try ProfileEditLimitsTests.limits()
        let stored = try storedProfile(basal: 0.1, targetLow: 80, targetHigh: 120)
        var draft = ProfileDraft(stored.values, singleTarget: true)
        draft.sensitivity[0].value = 60
        #expect(ProfileValidation.changedSchedules(from: stored.values, to: draft.values, singleTarget: true) == [.sensitivity])
        #expect(ProfileValidation.problems(for: .save(name: "Stored", original: stored, values: draft.values), limits: limits, singleTarget: true).isEmpty)
        #expect(ProfileValidation.problems(for: .save(name: "Stored", original: stored, values: draft.values), limits: limits).count == 1)
    }

    @Test("changed schedules are found per schedule, and a single-target range shown as low-only is unchanged")
    func changedSchedules() {
        let original = values(target: [(0, 100, 110)])
        #expect(ProfileValidation.changedSchedules(from: original, to: original).isEmpty)
        #expect(ProfileValidation.changedSchedules(from: original, to: values(basal: [(0, 0.85)], target: [(0, 100, 110)])) == [.basal])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(sens: [(0, 55)], target: [(0, 100, 110)])) == [.sensitivity])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(target: [(0, 100, 100)])) == [.correctionRange])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(target: [(0, 100, 100)]), singleTarget: true).isEmpty)
        #expect(ProfileValidation.changedSchedules(from: original, to: values(target: [(0, 105, 105)]), singleTarget: true) == [.correctionRange])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(carbRatio: [(0, 12)], target: [(0, 100, 110)])) == [.carbRatio])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(basal: [(0, 0.85), (23400, 1.0)], target: [(0, 100, 110)])) == [.basal])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(carbRatio: [(0, 10), (43200, 12)], target: [(0, 100, 110)])) == [.carbRatio])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(target: [(0, 100, 110), (43200, 100, 120)])) == [.correctionRange])
        #expect(ProfileValidation.changedSchedules(from: original, to: values(basal: [(0, 0.9), (21600, 1.0)], sens: [(0, 45)], target: [(0, 95, 110)])) == [.basal, .sensitivity, .correctionRange])
        let mmol = values(units: "mmol/L", sens: [(0, 2.8)], target: [(0, 5.5, 6.1)])
        #expect(ProfileValidation.changedSchedules(from: mmol, to: mmol).isEmpty)
        #expect(ProfileValidation.changedSchedules(from: mmol, to: values(units: "mmol/L", sens: [(0, 2.9)], target: [(0, 5.5, 6.1)])) == [.sensitivity])
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
