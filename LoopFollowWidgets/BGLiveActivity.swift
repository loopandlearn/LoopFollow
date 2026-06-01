// LoopFollow
// BGLiveActivity.swift

#if os(iOS)
    import ActivityKit
    import SwiftUI
    import WidgetKit

    // MARK: - Activity Attributes

    struct BGLiveActivityAttributes: ActivityAttributes {
        struct ContentState: Codable, Hashable {
            let bgValue: Int
            let direction: String
            let delta: Int?
            let bgTimestamp: Date
            let iob: Double?
            let cob: Double?
            let basalRate: Double?
            let scheduledBasal: Double?
            let history: [WidgetBGPoint]
            let units: String
            let updatedAt: Date

            init(from data: WidgetData) {
                bgValue = data.bgValue
                direction = data.direction
                delta = data.delta
                bgTimestamp = data.bgTimestamp
                iob = data.iob
                cob = data.cob
                basalRate = data.basalRate
                scheduledBasal = data.scheduledBasal
                history = data.history
                units = data.units
                updatedAt = data.updatedAt
            }
        }
    }

    // MARK: - Live Activity Configuration

    struct BGLiveActivityWidget: Widget {
        var body: some WidgetConfiguration {
            ActivityConfiguration(for: BGLiveActivityAttributes.self) { context in
                let data = widgetData(from: context.state)
                BGComplicationContent(
                    data: data,
                    displayDate: Date(),
                    useColor: true
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .activityBackgroundTint(.black.opacity(0.7))

            } dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.center) {
                        let data = widgetData(from: context.state)
                        BGComplicationContent(
                            data: data,
                            displayDate: Date(),
                            useColor: true
                        )
                    }
                } compactLeading: {
                    Text("\(context.state.bgValue)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(bgColor(for: context.state.bgValue))
                } compactTrailing: {
                    Text(context.state.direction)
                        .font(.system(size: 12))
                } minimal: {
                    Text("\(context.state.bgValue)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(bgColor(for: context.state.bgValue))
                }
            }
        }

        private func widgetData(from state: BGLiveActivityAttributes.ContentState) -> WidgetData {
            WidgetData(
                bgValue: state.bgValue,
                direction: state.direction,
                delta: state.delta,
                bgTimestamp: state.bgTimestamp,
                iob: state.iob,
                cob: state.cob,
                basalRate: state.basalRate,
                scheduledBasal: state.scheduledBasal,
                history: state.history,
                units: state.units,
                updatedAt: state.updatedAt
            )
        }

        private func bgColor(for bg: Int) -> Color {
            if bg < 70 || bg > 180 { return .red }
            if bg < 80 || bg > 170 { return .yellow }
            return .green
        }
    }
#endif
