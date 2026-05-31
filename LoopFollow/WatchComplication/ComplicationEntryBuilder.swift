// LoopFollow
// ComplicationEntryBuilder.swift

import ClockKit

// MARK: - Complication identifiers

enum ComplicationID {
    /// graphicCircular + graphicCorner with gauge arc (Complication 1).
    static let gaugeCorner = "LoopFollowGaugeCorner"
    /// graphicCorner stacked text only (Complication 2).
    static let stackCorner = "LoopFollowStackCorner"
    // DEBUG COMPLICATION — enabled for pipeline diagnostics.
    // Shows two timestamps to isolate pipeline failures:
    //   outer (top):  HH:mm of snapshot.updatedAt — when CGM data last reached the Watch
    //   inner (↺):    HH:mm when ClockKit last called getCurrentTimelineEntry
    // If outer changes but inner is stale → reloadTimeline() not firing or ClockKit ignoring it.
    // If inner changes but outer is stale → data delivery broken, complication rebuilding with old data.
    static let debugCorner = "LoopFollowDebugCorner"
}

// MARK: - Entry builder

enum ComplicationEntryBuilder {
    // MARK: - Live template

    static func template(
        for family: CLKComplicationFamily,
        snapshot: GlucoseSnapshot,
        identifier: String
    ) -> CLKComplicationTemplate? {
        switch family {
        case .graphicCircular:
            return graphicCircularTemplate(snapshot: snapshot)
        case .graphicCorner:
            switch identifier {
            case ComplicationID.stackCorner: return graphicCornerStackTemplate(snapshot: snapshot)
            case ComplicationID.debugCorner: return graphicCornerDebugTemplate(snapshot: snapshot)
            default: return graphicCornerGaugeTemplate(snapshot: snapshot)
            }
        default:
            return nil
        }
    }

    // MARK: - Stale template

    static func staleTemplate(for family: CLKComplicationFamily, identifier: String) -> CLKComplicationTemplate? {
        switch family {
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "--"),
                line2TextProvider: CLKSimpleTextProvider(text: "")
            )
        case .graphicCorner:
            switch identifier {
            case ComplicationID.stackCorner:
                return CLKComplicationTemplateGraphicCornerStackText(
                    innerTextProvider: CLKSimpleTextProvider(text: ""),
                    outerTextProvider: CLKSimpleTextProvider(text: "--")
                )
            case ComplicationID.debugCorner:
                return CLKComplicationTemplateGraphicCornerStackText(
                    innerTextProvider: CLKSimpleTextProvider(text: "STALE"),
                    outerTextProvider: CLKSimpleTextProvider(text: "--:--")
                )
            default:
                return staleGaugeTemplate()
            }
        default:
            return nil
        }
    }

    // MARK: - Placeholder template

    static func placeholderTemplate(for family: CLKComplicationFamily, identifier: String) -> CLKComplicationTemplate? {
        switch family {
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "---"),
                line2TextProvider: CLKSimpleTextProvider(text: "→")
            )
        case .graphicCorner:
            switch identifier {
            case ComplicationID.stackCorner:
                let outer = CLKSimpleTextProvider(text: "---")
                outer.tintColor = .green
                return CLKComplicationTemplateGraphicCornerStackText(
                    innerTextProvider: CLKSimpleTextProvider(text: "→ --"),
                    outerTextProvider: outer
                )
            case ComplicationID.debugCorner:
                return CLKComplicationTemplateGraphicCornerStackText(
                    innerTextProvider: CLKSimpleTextProvider(text: "DEBUG"),
                    outerTextProvider: CLKSimpleTextProvider(text: "--:--")
                )
            default:
                let outer = CLKSimpleTextProvider(text: "---")
                outer.tintColor = .green
                let gauge = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .green, fillFraction: 0)
                return CLKComplicationTemplateGraphicCornerGaugeText(
                    gaugeProvider: gauge,
                    leadingTextProvider: CLKSimpleTextProvider(text: "0"),
                    trailingTextProvider: nil,
                    outerTextProvider: outer
                )
            }
        default:
            return nil
        }
    }

    // MARK: - Graphic Circular

    // BG (top, colored) + trend arrow (bottom).

    private static func graphicCircularTemplate(snapshot: GlucoseSnapshot) -> CLKComplicationTemplate {
        let bgText = CLKSimpleTextProvider(text: WatchFormat.glucose(snapshot))
        bgText.tintColor = thresholdColor(for: snapshot)

        return CLKComplicationTemplateGraphicCircularStackText(
            line1TextProvider: bgText,
            line2TextProvider: CLKSimpleTextProvider(text: WatchFormat.trendArrow(snapshot))
        )
    }

    // MARK: - Graphic Corner — Gauge Text (Complication 1)

    // Gauge arc fills from 0 (fresh) to 100% (15 min stale).
    // Outer text: BG (colored). Leading text: delta.
    // Stale / isNotLooping → "⚠" in yellow, gauge full.

    private static func graphicCornerGaugeTemplate(snapshot: GlucoseSnapshot) -> CLKComplicationTemplate {
        guard snapshot.age < 900, !snapshot.isNotLooping else {
            return staleGaugeTemplate()
        }

        let fraction = Float(min(snapshot.age / 900.0, 1.0))
        let color = thresholdColor(for: snapshot)

        let bgText = CLKSimpleTextProvider(text: WatchFormat.glucose(snapshot))
        bgText.tintColor = color

        let gauge = CLKSimpleGaugeProvider(style: .fill, gaugeColor: color, fillFraction: fraction)

        return CLKComplicationTemplateGraphicCornerGaugeText(
            gaugeProvider: gauge,
            leadingTextProvider: CLKSimpleTextProvider(text: WatchFormat.delta(snapshot)),
            trailingTextProvider: nil,
            outerTextProvider: bgText
        )
    }

    private static func staleGaugeTemplate() -> CLKComplicationTemplate {
        let warnText = CLKSimpleTextProvider(text: "⚠")
        warnText.tintColor = .yellow

        let gauge = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .yellow, fillFraction: 1.0)

        return CLKComplicationTemplateGraphicCornerGaugeText(
            gaugeProvider: gauge,
            leadingTextProvider: nil,
            trailingTextProvider: nil,
            outerTextProvider: warnText
        )
    }

    // MARK: - Graphic Corner — Stacked Text (Complication 2)

    // Outer (top, large): BG value, colored.
    // Inner (bottom, small): "→ projected" (falls back to delta if no projection).
    // Stale / isNotLooping: outer = "--", inner = "".

    private static func graphicCornerStackTemplate(snapshot: GlucoseSnapshot) -> CLKComplicationTemplate {
        guard snapshot.age < 900, !snapshot.isNotLooping else {
            return CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: CLKSimpleTextProvider(text: ""),
                outerTextProvider: CLKSimpleTextProvider(text: "--")
            )
        }

        let bgText = CLKSimpleTextProvider(text: WatchFormat.glucose(snapshot))
        bgText.tintColor = thresholdColor(for: snapshot)

        let bottomLabel: String
        if let _ = snapshot.projected {
            // ⇢ = dashed arrow (U+21E2); swap for ▸ (U+25B8) if it renders poorly on-device
            bottomLabel = "\(WatchFormat.delta(snapshot)) | ⇢\(WatchFormat.projected(snapshot))"
        } else {
            bottomLabel = WatchFormat.delta(snapshot)
        }

        return CLKComplicationTemplateGraphicCornerStackText(
            innerTextProvider: CLKSimpleTextProvider(text: bottomLabel),
            outerTextProvider: bgText
        )
    }

    // MARK: - Graphic Corner — Debug (Complication 3)

    // Outer (top): HH:mm of the snapshot's updatedAt — when the CGM reading arrived.
    // Inner (bottom): "↺ HH:mm" — when ClockKit last called getCurrentTimelineEntry.
    //
    // Reading the two times tells you:
    //   outer changes  → Watch is receiving new data
    //   inner changes  → ClockKit is refreshing the complication face
    //   inner stale    → reloadTimeline is not being called or ClockKit is ignoring it

    private static func graphicCornerDebugTemplate(snapshot: GlucoseSnapshot) -> CLKComplicationTemplate {
        let dataTime = WatchFormat.updateTime(snapshot)
        let buildTime = WatchFormat.currentTime()

        return CLKComplicationTemplateGraphicCornerStackText(
            innerTextProvider: CLKSimpleTextProvider(text: "↺ \(buildTime)"),
            outerTextProvider: CLKSimpleTextProvider(text: dataTime)
        )
    }

    // MARK: - Threshold color

    /// snapshot.glucose is always in mg/dL (builder stores canonical mg/dL).
    static func thresholdColor(for snapshot: GlucoseSnapshot) -> UIColor {
        let t = LAAppGroupSettings.thresholdsMgdl()
        if snapshot.glucose < t.low { return .red }
        if snapshot.glucose > t.high { return .orange }
        return .green
    }
}
