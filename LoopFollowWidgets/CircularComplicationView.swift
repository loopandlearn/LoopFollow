// LoopFollow
// CircularComplicationView.swift

//
// Round complication for modular watch faces (accessoryCircular).
// Layout: staleness on top, BG center, delta + trend below.
// No color — transparent background, white/primary text.
// When reading is >=16 min stale, all text turns gray with a strikethrough line.

import SwiftUI
import WidgetKit

struct CircularComplicationView: View {
    let entry: BGEntry

    var body: some View {
        if let data = entry.data {
            let isStale = entry.displayDate.timeIntervalSince(data.bgTimestamp) >= 16 * 60

            ZStack {
                AccessoryWidgetBackground()

                VStack(spacing: -4) {
                    // Staleness — top
                    Text(stalenessText(data, displayDate: entry.displayDate))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isStale ? .secondary : .primary)
                        .lineLimit(1)

                    // BG value — center, biggest
                    Text(bgText(data))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isStale ? .secondary : bgDynamicColor(Double(data.bgValue)))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .widgetAccentable()
                        .overlay {
                            if isStale {
                                Rectangle()
                                    .frame(height: 1.5)
                                    .foregroundColor(.secondary)
                            }
                        }

                    // Trend arrow + delta — bottom
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(data.direction)
                            .baselineOffset(-1)
                        if let d = data.delta {
                            Text(deltaText(d, units: data.units))
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isStale ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Text("--")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func bgText(_ data: WidgetData) -> String {
        if data.units == "mmol/L" {
            return String(format: "%.1f", Double(data.bgValue) * 0.0555)
        }
        return "\(data.bgValue)"
    }

    private func deltaText(_ delta: Int, units: String) -> String {
        if units == "mmol/L" {
            let mmol = Double(delta) * 0.0555
            return String(format: "%+.1f", mmol)
        }
        return String(format: "%+d", delta)
    }

    private func stalenessText(_ data: WidgetData, displayDate: Date) -> String {
        let minutes = Int(displayDate.timeIntervalSince(data.bgTimestamp) / 60)
        if minutes < 1 { return "now" }
        return "\(minutes)m"
    }
}
