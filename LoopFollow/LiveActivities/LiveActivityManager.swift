// LoopFollow
// LiveActivityManager.swift

import ActivityKit
import Foundation

enum LiveActivityManager {
    static func start(emoji: String, name: String = "LoopFollow", staleAfter: TimeInterval? = 3600) throws -> Activity<LoopFollowWidgetAttributes> {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "LiveActivity", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live Activities disabled"])
        }
        let attributes = LoopFollowWidgetAttributes(name: name)
        let state = LoopFollowWidgetAttributes.ContentState(emoji: emoji)
        let content = ActivityContent(state: state, staleDate: staleAfter.map { .now.addingTimeInterval($0) })
        return try Activity.request(attributes: attributes, content: content)
    }

    static func update(_ activity: Activity<LoopFollowWidgetAttributes>, emoji: String, staleAfter: TimeInterval? = 3600) async {
        let state = LoopFollowWidgetAttributes.ContentState(emoji: emoji)
        let content = ActivityContent(state: state, staleDate: staleAfter.map { .now.addingTimeInterval($0) })
        await activity.update(content)
    }

    static func end(_ activity: Activity<LoopFollowWidgetAttributes>, finalEmoji: String? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        let state = LoopFollowWidgetAttributes.ContentState(emoji: finalEmoji ?? "✅")
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: dismissalPolicy)
    }
}
