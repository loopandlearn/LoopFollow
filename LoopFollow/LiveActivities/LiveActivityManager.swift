// LoopFollow
// LiveActivityManager.swift

import ActivityKit
import Foundation

enum LiveActivityManager {
    static func start(state: LoopFollowWidgetAttributes.ContentState,
                      name: String = "LoopFollow",
                      staleAfter: TimeInterval? = 15 * 60) throws -> Activity<LoopFollowWidgetAttributes>
    {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "LiveActivity", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live Activities disabled"])
        }
        let attributes = LoopFollowWidgetAttributes(name: name)
        let content = ActivityContent(state: state, staleDate: staleAfter.map { .now.addingTimeInterval($0) })
        return try Activity.request(attributes: attributes, content: content)
    }

    static func update(_ activity: Activity<LoopFollowWidgetAttributes>,
                       state: LoopFollowWidgetAttributes.ContentState,
                       staleAfter: TimeInterval? = 15 * 60) async
    {
        let content = ActivityContent(state: state, staleDate: staleAfter.map { .now.addingTimeInterval($0) })
        await activity.update(content)
    }

    static func end(_ activity: Activity<LoopFollowWidgetAttributes>,
                    finalState: LoopFollowWidgetAttributes.ContentState,
                    dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async
    {
        await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: dismissalPolicy)
    }
}
