// LoopFollow
// LoopFollowWatchWidgets.swift

import SwiftUI
import WidgetKit

@main
struct LoopFollowWatchWidgets: WidgetBundle {
    var body: some Widget {
        GlucoseComplication()
    }
}

struct GlucoseComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GlucoseComplication", provider: GlucoseTimelineProvider()) { entry in
            GlucoseComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("BG")
        .description("Latest BG from LoopFollow on your iPhone.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let state: WatchState?
}

/// Reads the state the watch app stored. One entry per minute keeps the
/// "minutes ago" text and the stale marking current until the next reload.
struct GlucoseTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> GlucoseEntry {
        GlucoseEntry(date: Date(), state: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (GlucoseEntry) -> Void) {
        completion(GlucoseEntry(date: Date(), state: WatchStateStore.load()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        let state = WatchStateStore.load()
        let now = Date()
        let entries = (0 ..< 30).map { minute in
            GlucoseEntry(date: now.addingTimeInterval(Double(minute) * 60), state: state)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
