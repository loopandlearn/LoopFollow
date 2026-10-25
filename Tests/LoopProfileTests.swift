// LoopFollow
// LoopProfileTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct LoopProfileTests {
    private func store(units: String, sens: Double, low: Double, high: Double) throws -> NSProfile.Store {
        let json = """
        {"timezone": "ETC/GMT-1", "units": "\(units)",
         "basal": [{"time": "00:00", "value": 0.85, "timeAsSeconds": 0}, {"time": "06:00", "value": 1.1, "timeAsSeconds": 21600}],
         "carbratio": [{"time": "00:00", "value": 10, "timeAsSeconds": 0}],
         "sens": [{"time": "00:00", "value": \(sens), "timeAsSeconds": 0}],
         "target_low": [{"time": "00:00", "value": \(low), "timeAsSeconds": 0}],
         "target_high": [{"time": "00:00", "value": \(high), "timeAsSeconds": 0}]}
        """
        return try JSONDecoder().decode(NSProfile.Store.self, from: Data(json.utf8))
    }

    @Test("fingerprint matches the value Loop computes for the same store entry")
    func fingerprint() throws {
        let mgdl = try LoopProfile(name: "Sport", store: store(units: "mg/dL", sens: 45, low: 100, high: 110))
        #expect(mgdl.fingerprint == "fec4f066b5a54ecd")
        let mmol = try LoopProfile(name: "Sport", store: store(units: "mmol/L", sens: 2.497_646_904_752_9, low: 5.550_747_991_045_533, high: 6.105_822_790_150_087))
        #expect(mmol.fingerprint == "f7d9520ff02af97c")
    }

    @Test("basal total weights each rate by how long it runs")
    func basalTotal() throws {
        let profile = try LoopProfile(name: "Sport", store: store(units: "mg/dL", sens: 45, low: 100, high: 110))
        #expect(abs(profile.basalTotal - (0.85 * 6 + 1.1 * 18)) < 0.000_1)
        #expect(profile.correctionRange == [LoopProfile.RangeItem(seconds: 0, low: 100, high: 110)])
    }

    @Test("the Default entry is left out and names are sorted")
    func savedProfiles() throws {
        let entry = try store(units: "mg/dL", sens: 45, low: 100, high: 110)
        let profile = NSProfile(store: ["Default": entry, "Work": entry, "Sport": entry], defaultProfile: "Work", units: "mg/dL",
                                bundleIdentifier: nil, isAPNSProduction: nil, deviceToken: nil, teamID: nil, expirationDate: nil,
                                startDate: nil, createdAt: nil, remoteCommands: nil, trioOverrides: nil, loopSettings: nil)
        let set = LoopProfileSet(profile)
        #expect(set.profiles.map(\.name) == ["Sport", "Work"])
        #expect(set.activeName == "Work")
    }
}
