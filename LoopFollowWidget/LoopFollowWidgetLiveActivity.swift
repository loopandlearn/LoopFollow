// LoopFollow
// LoopFollowWidgetLiveActivity.swift

import ActivityKit
import SwiftUI
import WidgetKit

struct LoopFollowWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LoopFollowWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

private extension LoopFollowWidgetAttributes {
    static var preview: LoopFollowWidgetAttributes {
        LoopFollowWidgetAttributes(name: "World")
    }
}

private extension LoopFollowWidgetAttributes.ContentState {
    static var smiley: LoopFollowWidgetAttributes.ContentState {
        LoopFollowWidgetAttributes.ContentState(emoji: "😀")
    }

    static var starEyes: LoopFollowWidgetAttributes.ContentState {
        LoopFollowWidgetAttributes.ContentState(emoji: "🤩")
    }
}
