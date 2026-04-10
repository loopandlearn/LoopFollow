// LoopFollow
// WatchComplicationProvider.swift

import ClockKit
import Foundation
import os.log

private let watchLog = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? "com.loopfollow.watch",
    category: "Watch"
)

final class WatchComplicationProvider: NSObject, CLKComplicationDataSource {
    // MARK: - Complication Descriptors

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        var descriptors: [CLKComplicationDescriptor] = [
            // Complication 1: BG + gauge arc (graphicCircular + graphicCorner)
            CLKComplicationDescriptor(
                identifier: ComplicationID.gaugeCorner,
                displayName: "LoopFollow",
                supportedFamilies: [.graphicCircular, .graphicCorner]
            ),
            // Complication 2: BG + projected BG stacked text (graphicCorner only)
            CLKComplicationDescriptor(
                identifier: ComplicationID.stackCorner,
                displayName: "LoopFollow Text",
                supportedFamilies: [.graphicCorner]
            ),
        ]
        #if DEBUG
            // DEBUG COMPLICATION — pipeline diagnostics only, not shipped in release builds.
            descriptors.append(
                CLKComplicationDescriptor(
                    identifier: ComplicationID.debugCorner,
                    displayName: "LoopFollow Debug",
                    supportedFamilies: [.graphicCorner]
                )
            )
        #endif
        handler(descriptors)
    }

    // MARK: - Timeline

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        // Whenever ClockKit calls us it hands us the CLKComplication object.
        // Cache it so WatchSessionReceiver can call reloadTimeline() even when
        // activeComplications is nil (common during background execution on watchOS 9+).
        WatchSessionReceiver.shared.cacheComplication(complication)

        // Prefer the file store (persists across launches); fall back to the in-memory
        // cache in case the file write hasn't completed or the store is unavailable.
        guard let snapshot = GlucoseSnapshotStore.shared.load()
            ?? WatchSessionReceiver.shared.lastSnapshot
        else {
            os_log("WatchComplicationProvider: no snapshot available (store and cache both nil)", log: watchLog, type: .error)
            handler(nil)
            return
        }

        os_log("WatchComplicationProvider: getCurrentTimelineEntry g=%d age=%ds id=%{public}@", log: watchLog, type: .info, Int(snapshot.glucose), Int(snapshot.age), complication.identifier)

        guard snapshot.age < 900 else {
            os_log("WatchComplicationProvider: snapshot stale (%d s)", log: watchLog, type: .debug, Int(snapshot.age))
            handler(staleEntry(for: complication))
            return
        }

        let template = ComplicationEntryBuilder.template(
            for: complication.family,
            snapshot: snapshot,
            identifier: complication.identifier
        )
        let entry = template.map {
            CLKComplicationTimelineEntry(date: snapshot.updatedAt, complicationTemplate: $0)
        }
        handler(entry)
    }

    func getTimelineEndDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        WatchSessionReceiver.shared.cacheComplication(complication)
        // Expire timeline 15 minutes after last reading
        // so Watch does not display indefinitely stale data
        if let snapshot = GlucoseSnapshotStore.shared.load() {
            handler(snapshot.updatedAt.addingTimeInterval(900))
        } else {
            handler(nil)
        }
    }

    func getPrivacyBehavior(
        for _: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        // Glucose is sensitive — hide on locked watch face
        handler(.hideOnLockScreen)
    }

    // MARK: - Placeholder

    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        handler(ComplicationEntryBuilder.placeholderTemplate(
            for: complication.family,
            identifier: complication.identifier
        ))
    }

    // MARK: - Private

    private func staleEntry(for complication: CLKComplication) -> CLKComplicationTimelineEntry? {
        let template = ComplicationEntryBuilder.staleTemplate(
            for: complication.family,
            identifier: complication.identifier
        )
        return template.map {
            CLKComplicationTimelineEntry(date: Date(), complicationTemplate: $0)
        }
    }
}
