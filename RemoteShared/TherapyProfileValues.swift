// LoopFollow
// TherapyProfileValues.swift

import CryptoKit
import Foundation

/// One entry of a therapy schedule: seconds from midnight and a value.
struct ProfileScheduleItem: Equatable, Hashable {
    let seconds: Int
    let value: Double
}

/// One correction range entry: seconds from midnight, low and high.
struct ProfileRangeItem: Equatable, Hashable {
    let seconds: Int
    let low: Double
    let high: Double
}

/// The four schedules of a therapy profile in the compact form remote profile commands carry:
/// `{"units", "basal": [[s, v]], "carbratio": [[s, v]], "sens": [[s, v]], "target": [[s, low, high]]}`.
/// Glucose values are in `units`.
struct TherapyProfileValues: Equatable, Encodable {
    static let mgdl = "mg/dL"
    static let mmol = "mmol/L"

    let units: String
    let basal: [ProfileScheduleItem]
    let carbRatio: [ProfileScheduleItem]
    let sensitivity: [ProfileScheduleItem]
    let target: [ProfileRangeItem]

    /// `mg/dL` or `mmol/L` for any spelling Nightscout uploaders use.
    static func normalizedUnits(_ units: String) -> String {
        units.lowercased().hasPrefix("mmol") ? mmol : mgdl
    }

    var fingerprint: String {
        Self.fingerprint(
            basal: basal,
            carbRatio: carbRatio,
            sensitivity: sensitivity,
            targetLow: target.map { ProfileScheduleItem(seconds: $0.seconds, value: $0.low) },
            targetHigh: target.map { ProfileScheduleItem(seconds: $0.seconds, value: $0.high) }
        )
    }

    /// The fingerprint Loop and Trio compute for a profile store entry:
    /// `basal=<seconds>:<value>,...;carbratio=...;sens=...;target_low=...;target_high=...` with values to three
    /// decimals in the entry's units, hashed with SHA-256, first 16 hex characters.
    static func fingerprint(
        basal: [ProfileScheduleItem],
        carbRatio: [ProfileScheduleItem],
        sensitivity: [ProfileScheduleItem],
        targetLow: [ProfileScheduleItem],
        targetHigh: [ProfileScheduleItem]
    ) -> String {
        let digest = SHA256.hash(data: Data(canonicalString(
            basal: basal,
            carbRatio: carbRatio,
            sensitivity: sensitivity,
            targetLow: targetLow,
            targetHigh: targetHigh
        ).utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }

    static func canonicalString(
        basal: [ProfileScheduleItem],
        carbRatio: [ProfileScheduleItem],
        sensitivity: [ProfileScheduleItem],
        targetLow: [ProfileScheduleItem],
        targetHigh: [ProfileScheduleItem]
    ) -> String {
        func encode(_ items: [ProfileScheduleItem]) -> String {
            items.map { "\($0.seconds):" + String(format: "%.3f", $0.value) }.joined(separator: ",")
        }
        return [
            "basal=" + encode(basal),
            "carbratio=" + encode(carbRatio),
            "sens=" + encode(sensitivity),
            "target_low=" + encode(targetLow),
            "target_high=" + encode(targetHigh),
        ].joined(separator: ";")
    }

    /// The decimals a value carries in a command, the same precision the fingerprint uses.
    static let encodedDecimals = 3

    /// `value` as the decimal number a command carries: rounded to `encodedDecimals`, so JSON holds `0.7`
    /// for 0.7 and never its binary approximation.
    static func encodedNumber(_ value: Double) -> Decimal {
        Decimal(string: String(format: "%.\(encodedDecimals)f", value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    /// The compact object for `JSONSerialization` (Loop commands).
    var jsonObject: [String: Any] {
        func number(_ value: Double) -> NSDecimalNumber {
            NSDecimalNumber(decimal: Self.encodedNumber(value))
        }
        return [
            "units": units,
            "basal": basal.map { [$0.seconds, number($0.value)] as [Any] },
            "carbratio": carbRatio.map { [$0.seconds, number($0.value)] as [Any] },
            "sens": sensitivity.map { [$0.seconds, number($0.value)] as [Any] },
            "target": target.map { [$0.seconds, number($0.low), number($0.high)] as [Any] },
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case units
        case basal
        case carbRatio = "carbratio"
        case sensitivity = "sens"
        case target
    }

    private struct Pair: Encodable {
        let item: ProfileScheduleItem

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(item.seconds)
            try container.encode(TherapyProfileValues.encodedNumber(item.value))
        }
    }

    private struct Triple: Encodable {
        let item: ProfileRangeItem

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(item.seconds)
            try container.encode(TherapyProfileValues.encodedNumber(item.low))
            try container.encode(TherapyProfileValues.encodedNumber(item.high))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(units, forKey: .units)
        try container.encode(basal.map(Pair.init), forKey: .basal)
        try container.encode(carbRatio.map(Pair.init), forKey: .carbRatio)
        try container.encode(sensitivity.map(Pair.init), forKey: .sensitivity)
        try container.encode(target.map(Triple.init), forKey: .target)
    }
}
