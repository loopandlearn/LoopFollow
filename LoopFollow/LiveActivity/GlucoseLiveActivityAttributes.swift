// LoopFollow
// GlucoseLiveActivityAttributes.swift

// swiftformat:disable indent
#if !targetEnvironment(macCatalyst)

import ActivityKit
import Foundation

struct GlucoseLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let snapshot: GlucoseSnapshot
        let seq: Int
        let reason: String
        let producedAt: Date

        init(snapshot: GlucoseSnapshot, seq: Int, reason: String, producedAt: Date) {
            self.snapshot = snapshot
            self.seq = seq
            self.reason = reason
            self.producedAt = producedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            snapshot = try container.decode(GlucoseSnapshot.self, forKey: .snapshot)
            seq = try container.decode(Int.self, forKey: .seq)
            reason = try container.decode(String.self, forKey: .reason)
            let producedAtInterval = try container.decode(Double.self, forKey: .producedAt)
            producedAt = Date(timeIntervalSince1970: producedAtInterval)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(snapshot, forKey: .snapshot)
            try container.encode(seq, forKey: .seq)
            try container.encode(reason, forKey: .reason)
            try container.encode(producedAt.timeIntervalSince1970, forKey: .producedAt)
        }

        private enum CodingKeys: String, CodingKey {
            case snapshot, seq, reason, producedAt
        }
    }

    /// Reserved for future metadata. Keep minimal for stability.
    let title: String
}

#endif
