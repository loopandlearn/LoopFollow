// LoopFollow
// TherapyProfile.swift

import Foundation
import HealthKit

/// A therapy profile from the Nightscout profile store of Loop or Trio.
struct TherapyProfile: Identifiable, Equatable {
    /// The store key of the profile that always exists (Loop `Default`, Trio `default`), matched case-insensitively.
    static let defaultName = "Default"

    let name: String
    let units: HKUnit
    let values: TherapyProfileValues
    /// Fingerprint of the store entry as uploaded. Commands that act on an existing profile send it so the
    /// phone only acts when its profile still has these values.
    let fingerprint: String
    /// False when the correction range is missing or its lows and highs do not line up, so the values can not be
    /// edited faithfully.
    let isWellFormed: Bool

    var id: String { name }

    var isDefault: Bool { Self.isDefaultName(name) }

    var basal: [ProfileScheduleItem] { values.basal }
    var carbRatio: [ProfileScheduleItem] { values.carbRatio }
    var sensitivity: [ProfileScheduleItem] { values.sensitivity }
    var correctionRange: [ProfileRangeItem] { values.target }

    static func isDefaultName(_ name: String) -> Bool {
        name.caseInsensitiveCompare(defaultName) == .orderedSame
    }

    /// `documentUnits` applies when the store entry has no `units` of its own.
    init(name: String, store: NSProfile.Store, documentUnits: String = TherapyProfileValues.mgdl) {
        func items(_ entries: [(Double, Double)]) -> [ProfileScheduleItem] {
            entries.map { ProfileScheduleItem(seconds: Int($0.0), value: $0.1) }
        }
        let basal = items(store.basal.map { ($0.timeAsSeconds, $0.value) })
        let carbRatio = items(store.carbratio.map { ($0.timeAsSeconds, $0.value) })
        let sensitivity = items(store.sens.map { ($0.timeAsSeconds, $0.value) })
        let targetLow = items((store.target_low ?? []).map { ($0.timeAsSeconds, $0.value) })
        let targetHigh = items((store.target_high ?? []).map { ($0.timeAsSeconds, $0.value) })

        self.name = name
        let unitsText = TherapyProfileValues.normalizedUnits(store.units ?? documentUnits)
        units = unitsText == TherapyProfileValues.mgdl ? .milligramsPerDeciliter : .millimolesPerLiter
        values = TherapyProfileValues(
            units: unitsText,
            basal: basal,
            carbRatio: carbRatio,
            sensitivity: sensitivity,
            target: zip(targetLow, targetHigh).map { ProfileRangeItem(seconds: $0.seconds, low: $0.value, high: $1.value) }
        )
        isWellFormed = !targetLow.isEmpty && targetLow.count == targetHigh.count && zip(targetLow, targetHigh).allSatisfy { $0.seconds == $1.seconds }
        fingerprint = TherapyProfileValues.fingerprint(basal: basal, carbRatio: carbRatio, sensitivity: sensitivity, targetLow: targetLow, targetHigh: targetHigh)
    }

    /// Scheduled basal over a full day, in units.
    var basalTotal: Double {
        Self.basalTotal(basal)
    }

    static func basalTotal(_ basal: [ProfileScheduleItem]) -> Double {
        basal.enumerated().reduce(0) { total, entry in
            let end = entry.offset + 1 < basal.count ? basal[entry.offset + 1].seconds : 24 * 3600
            return total + entry.element.value * Double(end - entry.element.seconds) / 3600
        }
    }

    /// Every profile in a profile document, Default first, then by name. Trio's `default` entry is named Default, which
    /// Trio's commands also accept.
    static func profiles(from profile: NSProfile) -> [TherapyProfile] {
        profile.store
            .map { TherapyProfile(name: isDefaultName($0.key) ? defaultName : $0.key, store: $0.value, documentUnits: profile.units) }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}

/// The profiles from the latest profile upload of Loop or Trio.
struct TherapyProfileSet: Equatable {
    let profiles: [TherapyProfile]
    /// `defaultProfile` of the document: the active profile.
    let activeName: String
    let uploadedAt: Date?
    let limits: ProfileEditLimits?
    let scheduledSwitches: ScheduledSwitchList

    init(profiles: [TherapyProfile], activeName: String, uploadedAt: Date?, limits: ProfileEditLimits? = nil, scheduledSwitches: ScheduledSwitchList = .empty) {
        self.profiles = profiles
        self.activeName = activeName
        self.uploadedAt = uploadedAt
        self.limits = limits
        self.scheduledSwitches = scheduledSwitches
    }

    init(_ profile: NSProfile) {
        self.init(
            profiles: TherapyProfile.profiles(from: profile),
            activeName: profile.defaultProfile,
            uploadedAt: profile.startDate.flatMap { NightscoutUtils.parseDate($0) },
            limits: profile.editLimits,
            scheduledSwitches: ScheduledSwitchList(profile)
        )
    }

    func isActive(_ profile: TherapyProfile) -> Bool {
        profile.name.caseInsensitiveCompare(activeName) == .orderedSame
    }

    var activeProfile: TherapyProfile? {
        profiles.first(where: isActive)
    }

    func profile(named name: String) -> TherapyProfile? {
        profiles.first { $0.name == name }
    }
}
