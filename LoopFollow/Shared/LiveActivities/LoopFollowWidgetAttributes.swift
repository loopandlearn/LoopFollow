// LoopFollow
// LoopFollowWidgetAttributes.swift

import ActivityKit
import Foundation

enum Palette: String, Codable, Hashable {
    case primary
    case green
    case yellow
    case red
}

struct LoopFollowWidgetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var emoji: String
        var bg: String
        var direction: String
        var delta: String
        var minAgo: String
        var iob: String
        var cob: String
        var zone: Int
        var displayName: String?
        var stale: Bool
        var bgTextColor: Palette
    }
}
