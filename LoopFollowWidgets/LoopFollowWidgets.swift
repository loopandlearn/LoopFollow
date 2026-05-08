// LoopFollow
// LoopFollowWidgets.swift

import WidgetKit
import SwiftUI

struct BGComplicationEntryView: View {
    let entry: BGEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        default:
            RectangularComplicationView(entry: entry)
        }
    }
}

struct BGComplicationWidget: Widget {
    let kind: String = "BGComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BGTimelineProvider()) { entry in
            BGComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "loopfollow://open"))
        }
        .configurationDisplayName("BG Monitor")
        .description("Blood glucose with trend and stats.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

@main
struct LoopFollowWidgetBundle: WidgetBundle {
    var body: some Widget {
        BGComplicationWidget()
        BolusShortcutWidget()
        MealShortcutWidget()
        OverrideShortcutWidget()
        TempTargetShortcutWidget()
        #if os(iOS)
        BGLiveActivityWidget()
        #endif
    }
}
