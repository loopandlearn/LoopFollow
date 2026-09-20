// LoopFollow
// BGTimelineProvider.swift

import SwiftUI
import WidgetKit

struct BGEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
    /// The reference "now" for staleness calculation. Each entry in the batch
    /// carries the *display time* so the staleness text is correct without a reload.
    let displayDate: Date
}

struct BGTimelineProvider: TimelineProvider {
    // MARK: - Required protocol

    func placeholder(in _: Context) -> BGEntry {
        BGEntry(date: .now, data: nil, displayDate: .now)
    }

    func getSnapshot(in _: Context, completion: @escaping (BGEntry) -> Void) {
        let entry = BGEntry(date: .now, data: WidgetData.load(), displayDate: .now)
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<BGEntry>) -> Void) {
        // Try to fetch fresh BG directly from Nightscout. This runs inside
        // the widget extension process — independent of the watch app and its
        // background task budget. The system calls getTimeline every ~5 min
        // for an active complication, so this is our most reliable update path.
        WidgetNightscoutFetcher.fetch { result in
            let data: WidgetData?
            switch result {
            case let .updated(d): data = d
            case let .unchanged(d): data = d
            case let .failed(d): data = d
            }

            let now = Date()

            // Generate entries every minute for the next hour.
            // Each entry carries a different `displayDate` so the staleness text
            // advances correctly without burning a reload.
            var entries: [BGEntry] = []
            for i in 0 ..< 60 {
                let entryDate = now.addingTimeInterval(Double(i) * 60)
                entries.append(BGEntry(date: entryDate, data: data, displayDate: entryDate))
            }

            // Ask for a fresh timeline in 5 minutes.
            let expiry = now.addingTimeInterval(5 * 60)
            let timeline = Timeline(entries: entries, policy: .after(expiry))
            completion(timeline)
        }
    }
}
