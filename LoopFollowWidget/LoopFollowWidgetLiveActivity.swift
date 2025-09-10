// LoopFollow
// LoopFollowWidgetLiveActivity.swift

import ActivityKit
import SwiftUI
import WidgetKit

struct LoopFollowWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LoopFollowWidgetAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.bg)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(colorFor(zone: context.state.zone))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.fill").foregroundStyle(.blue)
                            Text("IOB \(context.state.iob)")
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife").foregroundStyle(.orange)
                            Text("COB \(context.state.cob)")
                        }
                    }
                    .font(.caption2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Text(context.state.direction).font(.headline).bold()
                        Text(context.state.delta).font(.headline).monospacedDigit()
                        Text(formatMinAgo(context.state.minAgo))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
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

    // MARK: - Lock Screen three-column layout

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<LoopFollowWidgetAttributes>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // LEFT: BG + time-ago
            VStack(alignment: .leading, spacing: 6) {
                Text(context.state.bg)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(colorFor(zone: context.state.zone))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(formatMinAgo(context.state.minAgo))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .layoutPriority(2) // let BG keep space

            // MIDDLE: Trend + Delta (centered)
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Text(context.state.direction)
                        .font(.system(size: 26, weight: .heavy))
                    Text(context.state.delta)
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity) // flex column
            .layoutPriority(1)

            // RIGHT: IOB / COB (stacked with colored icons)
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("IOB \(context.state.iob)")
                }
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("COB \(context.state.cob)")
                }
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .frame(width: 120, alignment: .trailing) // keep right column tidy
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Helpers

private func formatMinAgo(_ minAgo: String) -> String {
    minAgo == "now" ? "now" : "\(minAgo) ago"
}

private func colorFor(zone: Int) -> Color {
    switch zone {
    case -1: return Color(red: 0.95, green: 0.3, blue: 0.3) // softer red
    case 1: return Color(red: 1.00, green: 0.80, blue: 0.20) // warm yellow
    default: return Color(red: 0.30, green: 0.85, blue: 0.40) // vibrant green
    }
}
