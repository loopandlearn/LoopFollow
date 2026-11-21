// LoopFollow
// NSProfile.swift

import Foundation

struct NSProfile: Decodable {
    struct Store: Decodable {
        struct BasalEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }

        struct SensEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }

        struct CarbRatioEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }

        struct TargetEntry: Decodable {
            let value: Double
            let time: String
            let timeAsSeconds: Double
        }

        let basal: [BasalEntry]
        let sens: [SensEntry]
        let carbratio: [CarbRatioEntry]
        let target_high: [TargetEntry]?
        let target_low: [TargetEntry]?
        let timezone: String

        /// Missing when the Nightscout profile editor saved the document; the document's `units` apply then.
        let units: String?
    }

    let store: [String: Store]
    let defaultProfile: String
    let units: String

    let bundleIdentifier: String?
    let isAPNSProduction: Bool?
    let deviceToken: String?
    let teamID: String?
    let expirationDate: String?
    let startDate: String?
    let createdAt: String?
    let remoteCommands: [String]?

    struct TrioOverrideEntry: Decodable {
        let name: String
        let duration: Double?
        let percentage: Double?
        let target: Double?
    }

    struct LoopSettings: Decodable {
        struct LoopOverridePreset: Decodable {
            let name: String
            let duration: Int?
            let targetRange: [Double]?
            let insulinNeedsScaleFactor: Double?
            let symbol: String?
        }

        let deviceToken: String?
        let bundleIdentifier: String?
        let minimumBGGuard: Double?
        let maximumBolus: Double?
        let maximumBasalRatePerHour: Double?
        let scheduleOverride: ScheduleOverride?
        let dosingStrategy: String?
        let overridePresets: [LoopOverridePreset]?
        let dosingEnabled: Bool?

        struct ScheduleOverride: Decodable {
            let symbol: String?
            let duration: Int?
            let insulinNeedsScaleFactor: Double?
            let name: String?
        }
    }

    let trioOverrides: [TrioOverrideEntry]?
    let loopSettings: LoopSettings?
    /// Bounds the uploader accepts for remotely edited profiles; nil when missing or malformed.
    let profileEditLimits: LenientDecoded<ProfileEditLimits>?
    /// The weekly profile starts; an entry that can not be read is nil, and so is a value that is not a list.
    let scheduledSwitches: LenientDecoded<[LenientDecoded<ScheduledProfileSwitch>]>?
    let scheduledSwitchesFingerprint: String?

    /// The glucose units of a store entry: its own, or the document's.
    func units(of store: Store) -> String {
        store.units ?? units
    }

    enum CodingKeys: String, CodingKey {
        case store
        case defaultProfile
        case units
        case bundleIdentifier
        case isAPNSProduction
        case deviceToken
        case trioOverrides = "overridePresets"
        case loopSettings
        case teamID
        case expirationDate
        case startDate
        case createdAt = "created_at"
        case remoteCommands
        case profileEditLimits
        case scheduledSwitches
        case scheduledSwitchesFingerprint
    }
}

extension NSProfile {
    /// A store entry that can not be read is left out, so one malformed profile does not hide the others.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([String: LenientDecoded<Store>].self, forKey: .store)
        store = entries.compactMapValues(\.value)
        defaultProfile = try container.decode(String.self, forKey: .defaultProfile)
        units = try container.decodeIfPresent(String.self, forKey: .units) ?? TherapyProfileValues.mgdl
        bundleIdentifier = try? container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        isAPNSProduction = try? container.decodeIfPresent(Bool.self, forKey: .isAPNSProduction)
        deviceToken = try? container.decodeIfPresent(String.self, forKey: .deviceToken)
        teamID = try? container.decodeIfPresent(String.self, forKey: .teamID)
        expirationDate = try? container.decodeIfPresent(String.self, forKey: .expirationDate)
        startDate = try? container.decodeIfPresent(String.self, forKey: .startDate)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        remoteCommands = try? container.decodeIfPresent([String].self, forKey: .remoteCommands)
        trioOverrides = try? container.decodeIfPresent([TrioOverrideEntry].self, forKey: .trioOverrides)
        loopSettings = try? container.decodeIfPresent(LoopSettings.self, forKey: .loopSettings)
        profileEditLimits = try container.decodeIfPresent(LenientDecoded<ProfileEditLimits>.self, forKey: .profileEditLimits)
        scheduledSwitches = try container.decodeIfPresent(LenientDecoded<[LenientDecoded<ScheduledProfileSwitch>]>.self, forKey: .scheduledSwitches)
        scheduledSwitchesFingerprint = try? container.decodeIfPresent(String.self, forKey: .scheduledSwitchesFingerprint)
    }
}
