// LoopFollow
// ProfileEditLimitsTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct ProfileEditLimitsTests {
    static let contractLimitsJSON = """
    {"units": "mg/dL", "maxBasal": 3.0, "basalRates": [0, 0.05, 0.1, 0.15, 3.0, 3.05],
     "carbRatio": {"min": 2, "max": 150, "step": 0.1, "recommendedMin": 4, "recommendedMax": 28},
     "sensitivity": {"min": 10, "max": 500, "step": 1, "recommendedMin": 16, "recommendedMax": 399},
     "target": {"min": 87, "max": 180, "step": 1, "recommendedMin": 100, "recommendedMax": 115},
     "maxSegments": 48, "segmentSeconds": 1800}
    """

    static func limits(_ json: String = contractLimitsJSON) throws -> ProfileEditLimits {
        try JSONDecoder().decode(ProfileEditLimits.self, from: Data(json.utf8))
    }

    private func profileDocument(limits: String?) throws -> NSProfile {
        let limitsField = limits.map { ", \"profileEditLimits\": \($0)" } ?? ""
        let json = """
        {"defaultProfile": "Default", "units": "mg/dL", "store": {}\(limitsField)}
        """
        return try JSONDecoder().decode(NSProfile.self, from: Data(json.utf8))
    }

    @Test("profileEditLimits is read from the profile document")
    func parsesFromDocument() throws {
        let document = try profileDocument(limits: Self.contractLimitsJSON)
        let limits = try #require(document.editLimits)
        #expect(limits.units == "mg/dL")
        #expect(limits.maxBasal == 3.0)
        #expect(limits.carbRatio == .init(min: 2, max: 150, step: 0.1, recommendedMin: 4, recommendedMax: 28))
        #expect(limits.target.recommendedMax == 115)
        #expect(limits.basalMinimum == nil)
        #expect(limits.segmentLimit == 48)
        #expect(limits.isUsable)
    }

    @Test("a missing or malformed block leaves the limits out and keeps the document")
    func missingOrMalformed() throws {
        #expect(try profileDocument(limits: nil).editLimits == nil)
        let malformed = try profileDocument(limits: "{\"units\": \"mg/dL\", \"maxBasal\": \"lots\"}")
        #expect(malformed.editLimits == nil)
        #expect(malformed.defaultProfile == "Default")
    }

    @Test("recommended bounds and the basal minimum are optional")
    func optionalKeys() throws {
        let limits = try Self.limits("""
        {"units": "mmol/L", "maxBasal": 2, "basalRates": [0, 0.05, 0.1, 2, 2.5], "basalMinimum": 0.05,
         "carbRatio": {"min": 1, "max": 99, "step": 1}, "sensitivity": {"min": 0.5, "max": 20, "step": 0.1},
         "target": {"min": 4.5, "max": 10, "step": 0.1}, "maxSegments": 48, "segmentSeconds": 1800}
        """)
        #expect(limits.allowedBasalRates == [0.05, 0.1, 2])
        #expect(!limits.isAllowedBasalRate(0))
        #expect(!limits.isAllowedBasalRate(2.5))
        #expect(limits.status(of: 30, in: .carbRatio) == .ok)
        #expect(limits.normalizedUnits == "mmol/L")
    }

    @Test("allowed basal rates stop at max basal")
    func basalRates() throws {
        let limits = try Self.limits()
        #expect(limits.allowedBasalRates == [0, 0.05, 0.1, 0.15, 3.0])
        #expect(limits.status(of: 0.1, in: .basal) == .ok)
        #expect(limits.status(of: 0.12, in: .basal) == .notAllowed)
        #expect(limits.status(of: 3.05, in: .basal) == .notAllowed)
    }

    @Test("range values follow the step without floating point noise")
    func rangeValues() throws {
        let limits = try Self.limits()
        let ratios = limits.carbRatio.values
        #expect(ratios.first == 2)
        #expect(ratios.last == 150)
        #expect(ratios.count == 1481)
        #expect(ratios[1] == 2.1)
        #expect(ratios[3] == 2.3)
        #expect(limits.target.values.count == 94)
        #expect(ProfileEditLimits.decimals(of: 0.05) == 2)
        #expect(ProfileEditLimits.decimals(of: 1) == 0)
    }

    @Test("status separates hard bounds from recommended bounds")
    func status() throws {
        let limits = try Self.limits()
        #expect(limits.status(of: 100, in: .correctionRange) == .ok)
        #expect(limits.status(of: 90, in: .correctionRange) == .outsideRecommended)
        #expect(limits.status(of: 86, in: .correctionRange) == .notAllowed)
        #expect(limits.status(of: 181, in: .correctionRange) == .notAllowed)
        #expect(limits.status(of: 3, in: .carbRatio) == .outsideRecommended)
        #expect(limits.status(of: 1.9, in: .carbRatio) == .notAllowed)
        #expect(limits.status(of: .nan, in: .sensitivity) == .notAllowed)
    }

    @Test("the pump's basal entry limit caps basal schedules only")
    func maxBasalSegments() throws {
        let plain = try Self.limits()
        #expect(plain.maxBasalSegments == nil)
        #expect(plain.segmentLimit(for: .basal) == 48)
        let omnipod = try Self.limits(Self.contractLimitsJSON.replacingOccurrences(of: "\"maxSegments\": 48", with: "\"maxSegments\": 48, \"maxBasalSegments\": 24"))
        #expect(omnipod.maxBasalSegments == 24)
        #expect(omnipod.isUsable)
        #expect(omnipod.segmentLimit(for: .basal) == 24)
        #expect(omnipod.segmentLimit(for: .carbRatio) == 48)
        #expect(omnipod.segmentLimit(for: .correctionRange) == 48)
        let generous = try Self.limits(Self.contractLimitsJSON.replacingOccurrences(of: "\"maxSegments\": 48", with: "\"maxSegments\": 12, \"maxBasalSegments\": 48"))
        #expect(generous.segmentLimit(for: .basal) == 12)
        let zero = try Self.limits(Self.contractLimitsJSON.replacingOccurrences(of: "\"maxSegments\": 48", with: "\"maxSegments\": 48, \"maxBasalSegments\": 0"))
        #expect(!zero.isUsable)
    }

    @Test("inconsistent limits are not usable")
    func unusable() throws {
        let badGrid = try Self.limits(Self.contractLimitsJSON.replacingOccurrences(of: "\"segmentSeconds\": 1800", with: "\"segmentSeconds\": 1700"))
        #expect(!badGrid.isUsable)
        let badStep = try Self.limits(Self.contractLimitsJSON.replacingOccurrences(of: "\"step\": 0.1", with: "\"step\": 0"))
        #expect(!badStep.isUsable)
        #expect(ProfileEditing.blocker(limits: badStep, remote: .trio) != nil)
        let missing = try #require(ProfileEditing.blocker(limits: nil, remote: .loop))
        #expect(missing.contains("pump"))
        #expect(try !#require(ProfileEditing.blocker(limits: nil, remote: .trio)).contains("pump"))
        #expect(try ProfileEditing.blocker(limits: Self.limits(), remote: .loop) == nil)
    }
}
