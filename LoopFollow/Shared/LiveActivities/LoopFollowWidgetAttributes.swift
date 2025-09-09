// LoopFollow
// LoopFollowWidgetAttributes.swift

import ActivityKit
import Foundation

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
    }

    var name: String
}
