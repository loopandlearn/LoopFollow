// LoopFollow
// LoopProfile.swift

import CryptoKit
import Foundation
import HealthKit

/// A saved Loop profile from the Nightscout profile store, offered for a remote switch.
struct LoopProfile: Identifiable, Equatable {
    struct Item: Equatable {
        let seconds: Int
        let value: Double
    }

    struct RangeItem: Equatable {
        let seconds: Int
        let low: Double
        let high: Double
    }

    /// Loop lists this in `remoteCommands` when it accepts remote profile switches.
    static let switchCommand = "profile-switch"

    let name: String
    let units: HKUnit
    let basal: [Item]
    let carbRatio: [Item]
    let sensitivity: [Item]
    let correctionRange: [RangeItem]
    /// Sent with the switch command. Loop only switches when its saved profile has the same fingerprint.
    let fingerprint: String

    var id: String { name }

    init(name: String, store: NSProfile.Store) {
        func items(_ entries: [(Double, Double)]) -> [Item] {
            entries.map { Item(seconds: Int($0.0), value: $0.1) }
        }
        let basal = items(store.basal.map { ($0.timeAsSeconds, $0.value) })
        let carbRatio = items(store.carbratio.map { ($0.timeAsSeconds, $0.value) })
        let sensitivity = items(store.sens.map { ($0.timeAsSeconds, $0.value) })
        let targetLow = items((store.target_low ?? []).map { ($0.timeAsSeconds, $0.value) })
        let targetHigh = items((store.target_high ?? []).map { ($0.timeAsSeconds, $0.value) })

        self.name = name
        units = store.units.lowercased() == "mg/dl" ? .milligramsPerDeciliter : .millimolesPerLiter
        self.basal = basal
        self.carbRatio = carbRatio
        self.sensitivity = sensitivity
        correctionRange = zip(targetLow, targetHigh).map { RangeItem(seconds: $0.seconds, low: $0.value, high: $1.value) }
        fingerprint = Self.fingerprint(basal: basal, carbRatio: carbRatio, sensitivity: sensitivity, targetLow: targetLow, targetHigh: targetHigh)
    }

    /// Scheduled basal over a full day, in units.
    var basalTotal: Double {
        basal.enumerated().reduce(0) { total, entry in
            let end = entry.offset + 1 < basal.count ? basal[entry.offset + 1].seconds : 24 * 3600
            return total + entry.element.value * Double(end - entry.element.seconds) / 3600
        }
    }

    /// Saved profiles in a Loop profile document, by name. `Default` mirrors the active settings and is left out.
    static func profiles(from profile: NSProfile) -> [LoopProfile] {
        profile.store
            .filter { $0.key != "Default" }
            .map { LoopProfile(name: $0.key, store: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Matches Loop's fingerprint of a profile store entry:
    /// `basal=<seconds>:<value>,...;carbratio=...;sens=...;target_low=...;target_high=...` with values to three
    /// decimals, hashed with SHA-256, first 16 hex characters.
    static func fingerprint(basal: [Item], carbRatio: [Item], sensitivity: [Item], targetLow: [Item], targetHigh: [Item]) -> String {
        func encode(_ items: [Item]) -> String {
            items.map { "\($0.seconds):" + String(format: "%.3f", $0.value) }.joined(separator: ",")
        }
        let canonical = [
            "basal=" + encode(basal),
            "carbratio=" + encode(carbRatio),
            "sens=" + encode(sensitivity),
            "target_low=" + encode(targetLow),
            "target_high=" + encode(targetHigh),
        ].joined(separator: ";")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}

/// The saved profiles from the latest Loop profile upload.
struct LoopProfileSet: Equatable {
    let profiles: [LoopProfile]
    let activeName: String
    let uploadedAt: Date?

    init(profiles: [LoopProfile], activeName: String, uploadedAt: Date?) {
        self.profiles = profiles
        self.activeName = activeName
        self.uploadedAt = uploadedAt
    }

    init(_ profile: NSProfile) {
        self.init(
            profiles: LoopProfile.profiles(from: profile),
            activeName: profile.defaultProfile,
            uploadedAt: profile.startDate.flatMap { NightscoutUtils.parseDate($0) }
        )
    }
}
