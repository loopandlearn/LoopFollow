// LoopFollow
// ScheduledProfileSwitch.swift

import CryptoKit
import Foundation

/// A weekly start of a profile: from `time` on `weekday` the profile is active until the next start.
/// The compact form the Nightscout profile document and the remote commands carry:
/// `{"id", "profile", "weekday", "time", "paused"}`, with `paused` only when true.
struct ScheduledProfileSwitch: Equatable, Hashable, Identifiable, Codable {
    /// Two starts per weekday.
    static let maxCount = 14

    let id: String
    var profile: String
    /// 1–7, Sunday = 1 (`Calendar`'s weekday index).
    var weekday: Int
    /// Seconds from midnight in the profile time zone, on a whole minute.
    var time: Int
    /// A paused start does not run until it is resumed.
    var paused: Bool

    init(id: String = UUID().uuidString, profile: String, weekday: Int, time: Int, paused: Bool = false) {
        self.id = id
        self.profile = profile
        self.weekday = weekday
        self.time = time
        self.paused = paused
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case profile
        case weekday
        case date
        case time
        case paused
    }

    private struct UnsupportedEntry: Error {}

    /// A one-off entry (`date`) or a time that is not whole seconds does not decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard !container.contains(.date) else { throw UnsupportedEntry() }
        id = try container.decode(String.self, forKey: .id)
        profile = try container.decode(String.self, forKey: .profile)
        weekday = try container.decode(Int.self, forKey: .weekday)
        let seconds = try container.decode(Double.self, forKey: .time)
        guard seconds.rounded() == seconds, abs(seconds) < 1e9 else { throw UnsupportedEntry() }
        time = Int(seconds)
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profile, forKey: .profile)
        try container.encode(weekday, forKey: .weekday)
        try container.encode(time, forKey: .time)
        if paused {
            try container.encode(true, forKey: .paused)
        }
    }

    /// The compact object for `JSONSerialization` (Loop commands).
    var jsonObject: [String: Any] {
        var object: [String: Any] = ["id": id, "profile": profile, "weekday": weekday, "time": time]
        if paused { object["paused"] = true }
        return object
    }

    /// `profile=<name>;weekday=<1–7>;date=-;time=<seconds>;paused=<true|false>`. `date` is always `-`: every entry is
    /// weekly.
    var canonicalString: String {
        "profile=\(profile);weekday=\(weekday);date=-;time=\(time);paused=\(paused)"
    }

    /// The canonical strings of all entries, sorted and joined with `|`. `id` is identity, not content, and is left out.
    static func canonicalString(_ entries: [ScheduledProfileSwitch]) -> String {
        entries.map(\.canonicalString).sorted().joined(separator: "|")
    }

    /// The fingerprint Loop and Trio compute for the list: SHA-256 of the canonical string, first 16 hex characters.
    static func fingerprint(_ entries: [ScheduledProfileSwitch]) -> String {
        let digest = SHA256.hash(data: Data(canonicalString(entries).utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}
