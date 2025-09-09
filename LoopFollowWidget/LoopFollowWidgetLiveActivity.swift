// LoopFollow
// LoopFollowWidgetLiveActivity.swift

import ActivityKit
import SwiftUI
import WidgetKit

struct LoopFollowWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LoopFollowWidgetAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Text(context.state.bg)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(colorFor(zone: context.state.zone))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(context.state.direction)
                                .font(.system(size: 22, weight: .heavy))
                                .lineLimit(1)

                            Text(context.state.delta)
                                .font(.system(size: 22, weight: .semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)

                        HStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Image(systemName: "drop.fill")
                                Text("IOB \(context.state.iob)")
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "fork.knife")
                                Text("COB \(context.state.cob)")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(context.state.minAgo)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.direction).bold()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.delta).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Text(context.state.bg)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(colorFor(zone: context.state.zone))
                        Text("IOB \(context.state.iob) • COB \(context.state.cob)")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text(context.state.direction)
            } compactTrailing: {
                Text(context.state.bg).monospacedDigit()
            } minimal: {
                Text(context.state.emoji)
            }
            .keylineTint(colorFor(zone: context.state.zone))
        }
    }
}

private func colorFor(zone: Int) -> Color {
    switch zone {
    case -1: return .red
    case 1: return .yellow
    default: return .green
    }
}
