// LoopFollow
// BGTimelineProvider.swift
//
// Aggressive refresh strategy for near-real-time BG complication updates:
//
// 1. MULTI-ENTRY TIMELINE: Generate 60 entries (one per minute for 1 hour) from a
//    single data snapshot. Each entry has its own `date` so WidgetKit displays
//    them at the correct time — the staleness counter advances naturally without
//    needing a reload. These cost zero budget; only timeline *reloads* count.
//
// 2. APP-DRIVEN RELOADS: BGFetcher calls WidgetCenter.shared.reloadAllTimelines()
//    every time new BG data arrives (~every 5 min while foregrounded). Each reload
//    generates a fresh batch of 12 entries.
//
// 3. BACKGROUND APP REFRESH: The watch app schedules WKApplicationRefreshBackgroundTask
//    every ~15 min. When it fires, the app fetches new data from Nightscout/Dexcom
//    and reloads timelines — even when the app isn't on screen.
//
// 4. TIMELINE RELOAD POLICY: .after(next) requests the system reload in 5 minutes.
//    Combined with the pre-generated entries, the complication always has something
//    fresh to display even if the budget is exhausted for a while.
//
// Net effect: complication updates every ~5 min in practice, with worst-case ~15 min
// from background refresh, matching or exceeding apps like SweetDreams.

import WidgetKit
import SwiftUI

struct BGEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
    /// The reference "now" for staleness calculation. Each entry in the batch
    /// carries the *display time* so the staleness text is correct without a reload.
    let displayDate: Date
}

struct BGTimelineProvider: TimelineProvider {

    // MARK: - Required protocol

    func placeholder(in context: Context) -> BGEntry {
        BGEntry(date: .now, data: nil, displayDate: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (BGEntry) -> Void) {
        let entry = BGEntry(date: .now, data: WidgetData.load(), displayDate: .now)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BGEntry>) -> Void) {
        // Try to fetch fresh BG directly from Nightscout. This runs inside
        // the widget extension process — independent of the watch app and its
        // background task budget. The system calls getTimeline every ~5 min
        // for an active complication, so this is our most reliable update path.
        WidgetNightscoutFetcher.fetch { result in
            let data: WidgetData?
            switch result {
            case .updated(let d):  data = d
            case .unchanged(let d): data = d
            case .failed(let d):   data = d
            }

            let now = Date()

            // Generate entries every minute for the next hour.
            // Each entry carries a different `displayDate` so the staleness text
            // advances correctly without burning a reload.
            var entries: [BGEntry] = []
            for i in 0..<60 {
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
