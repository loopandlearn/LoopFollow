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
    /// Sample values drawn for the redacted placeholder and the face gallery.
    var isPlaceholder = false
}

/// Reads the state the watch app stored. One entry per minute keeps the
/// "minutes ago" text and the stale marking current until the next reload.
struct GlucoseTimelineProvider: TimelineProvider {
    /// How soon to read again when the stored state could not be read.
    private static let retryAfter: TimeInterval = 10 * 60

    func placeholder(in _: Context) -> GlucoseEntry {
        GlucoseEntry(date: Date(), state: nil, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        let state = WatchStateStore.load()
        completion(GlucoseEntry(date: Date(), state: state, isPlaceholder: state == nil && context.isPreview))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        let now = Date()
        guard let state = WatchStateStore.load() else {
            completion(Timeline(entries: [GlucoseEntry(date: now, state: nil)], policy: .after(now.addingTimeInterval(Self.retryAfter))))
            return
        }
        let entries = (0 ..< 30).map { minute in
            GlucoseEntry(date: now.addingTimeInterval(Double(minute) * 60), state: state)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
