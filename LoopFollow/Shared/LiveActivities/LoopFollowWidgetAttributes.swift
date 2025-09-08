// LoopFollow
// LoopFollowWidgetAttributes.swift

import ActivityKit
import Foundation

struct LoopFollowWidgetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var emoji: String
    }

    var name: String
}
