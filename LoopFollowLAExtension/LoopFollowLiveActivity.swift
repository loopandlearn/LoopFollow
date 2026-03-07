//
//  LoopFollowLiveActivity.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-24.
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct LoopFollowLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseLiveActivityAttributes.self) { context in
            // LOCK SCREEN / BANNER UI
            LockScreenLiveActivityView(state: context.state/*, activityID: context.activityID*/)
                .id(context.state.seq) // force SwiftUI to re-render on every update
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(LAColors.backgroundTint(for: context.state.snapshot))
                .applyActivityContentMarginsFixIfAvailable()
            } dynamicIsland: { context in
            // DYNAMIC ISLAND UI
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandLeadingView(snapshot: context.state.snapshot)
                        .id(context.state.seq)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandTrailingView(snapshot: context.state.snapshot)
                        .id(context.state.seq)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandBottomView(snapshot: context.state.snapshot)
                        .id(context.state.seq)
                }
            } compactLeading: {
                DynamicIslandCompactLeadingView(snapshot: context.state.snapshot)
                    .id(context.state.seq)
            } compactTrailing: {
                DynamicIslandCompactTrailingView(snapshot: context.state.snapshot)
                    .id(context.state.seq)
            } minimal: {
                DynamicIslandMinimalView(snapshot: context.state.snapshot)
                    .id(context.state.seq)
            }
            .keylineTint(LAColors.keyline(for: context.state.snapshot).opacity(0.75))
        }
    }
}

// MARK: - Live Activity content margins helper

private extension View {
    @ViewBuilder
    func applyActivityContentMarginsFixIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            // Use the generic SwiftUI API available in iOS 17+ (no placement enum)
            self.contentMargins(Edge.Set.all, 0)
        } else {
            self
        }
    }
}

// MARK: - Lock Screen Contract View
@available(iOS 16.1, *)
private struct LockScreenLiveActivityView: View {
    let state: GlucoseLiveActivityAttributes.ContentState
    /*let activityID: String*/
    
    var body: some View {
        let s = state.snapshot

        HStack(spacing: 12) {

            // LEFT: Glucose + trend, update time below
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(LAFormat.glucose(s))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(LAFormat.trendArrow(s))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                }

                Text("Last Update: \(LAFormat.updated(s))")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(width: 168, alignment: .leading)
            .layoutPriority(2)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 1)
                .padding(.vertical, 8)

            // RIGHT: 2x2 grid — delta/proj | iob/cob
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    MetricBlock(label: "Delta", value: LAFormat.delta(s))
                    MetricBlock(label: "IOB", value: LAFormat.iob(s))
                }
                HStack(spacing: 16) {
                    MetricBlock(label: "Proj", value: LAFormat.projected(s))
                    MetricBlock(label: "COB", value: LAFormat.cob(s))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .overlay(
            Group {
                if state.snapshot.isNotLooping {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: UIColor.systemRed).opacity(0.85))
                        Text("Not Looping")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(1.5)
                    }
                }
            }
        )
    }
}

private struct MetricBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: 64, alignment: .leading) // consistent 2×2 columns
    }
}

// MARK: - Dynamic Island

@available(iOS 16.1, *)
private struct DynamicIslandLeadingView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            VStack(alignment: .leading, spacing: 2) {
                Text("⚠️ Not Looping")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(LAFormat.glucose(snapshot))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(LAFormat.trendArrow(snapshot))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.top, 2)
                }
                Text(LAFormat.delta(snapshot))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DynamicIslandTrailingView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 3) {
                Text("Upd \(LAFormat.updated(snapshot))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Proj \(LAFormat.projected(snapshot))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
    }
}

@available(iOS 16.1, *)
private struct DynamicIslandBottomView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            Text("Loop has not reported in 15+ minutes")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } else {
            HStack(spacing: 14) {
                Text("IOB \(LAFormat.iob(snapshot))")
                Text("COB \(LAFormat.cob(snapshot))")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }
}

@available(iOS 16.1, *)
private struct DynamicIslandCompactTrailingView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            Text("Not Looping")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text(LAFormat.trendArrow(snapshot))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}

@available(iOS 16.1, *)
private struct DynamicIslandCompactLeadingView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            Text("⚠️")
                .font(.system(size: 14))
        } else {
            Text(LAFormat.glucose(snapshot))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

@available(iOS 16.1, *)
private struct DynamicIslandMinimalView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            Text("⚠️")
                .font(.system(size: 12))
        } else {
            Text(LAFormat.glucose(snapshot))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Formatting

private enum LAFormat {

    // MARK: Glucose

    static func glucose(_ s: GlucoseSnapshot) -> String {
        switch s.unit {
        case .mgdl:
            return String(Int(round(s.glucose)))
        case .mmol:
            // 1 decimal always (contract: clinical, consistent)
            return String(format: "%.1f", s.glucose)
        }
    }

    static func delta(_ s: GlucoseSnapshot) -> String {
        switch s.unit {
        case .mgdl:
            let v = Int(round(s.delta))
            if v == 0 { return "0" }
            return v > 0 ? "+\(v)" : "\(v)"

        case .mmol:
            // Treat tiny fluctuations as 0.0 to avoid “+0.0” noise
            let d = (abs(s.delta) < 0.05) ? 0.0 : s.delta
            if d == 0 { return "0.0" }
            return d > 0 ? String(format: "+%.1f", d) : String(format: "%.1f", d)
        }
    }

    // MARK: Trend

    static func trendArrow(_ s: GlucoseSnapshot) -> String {
        // Map to the common clinical arrows; keep unknown as a neutral dash.
        switch s.trend {
        case .upFast: return "↑↑"
        case .up: return "↑"
        case .flat: return "→"
        case .down: return "↓"
        case .downFast: return "↓↓"
        case .unknown: return "–"
        }
    }

    // MARK: Secondary

    static func iob(_ s: GlucoseSnapshot) -> String {
        guard let v = s.iob else { return "—" }
        // Contract-friendly: one decimal, no unit suffix
        return String(format: "%.1f", v)
    }

    static func cob(_ s: GlucoseSnapshot) -> String {
        guard let v = s.cob else { return "—" }
        // Contract-friendly: whole grams
        return String(Int(round(v)))
    }

    static func projected(_ s: GlucoseSnapshot) -> String {
        guard let v = s.projected else { return "—" }
        switch s.unit {
        case .mgdl:
            return String(Int(round(v)))
        case .mmol:
            return String(format: "%.1f", v)
        }
    }

    // MARK: Update time

    private static let hhmmFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateFormat = "HH:mm" // 24h format
        return df
    }()

    private static let hhmmssFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    static func hhmmss(_ date: Date) -> String {
        hhmmssFormatter.string(from: date)
    }
    
    static func updated(_ s: GlucoseSnapshot) -> String {
        hhmmFormatter.string(from: s.updatedAt)
    }
}

// MARK: - Threshold-driven colors (Option A, App Group-backed)

private enum LAColors {

    static func backgroundTint(for snapshot: GlucoseSnapshot) -> Color {
        let mgdl = toMgdl(snapshot)
    
        let t = LAAppGroupSettings.thresholdsMgdl()
        let low = t.low
        let high = t.high
    
        if mgdl < low {
            let raw = 0.48 + (0.85 - 0.48) * ((low - mgdl) / (low - 54.0))
            let opacity = min(max(raw, 0.48), 0.85)
            return Color(uiColor: UIColor.systemRed).opacity(opacity)

        } else if mgdl > high {
            let raw = 0.44 + (0.85 - 0.44) * ((mgdl - high) / (324.0 - high))
            let opacity = min(max(raw, 0.44), 0.85)
            return Color(uiColor: UIColor.systemOrange).opacity(opacity)
            
        } else {
            // In range: fixed at your existing value
            return Color(uiColor: UIColor.systemGreen).opacity(0.36)
        }
    }


    static func keyline(for snapshot: GlucoseSnapshot) -> Color {
        let mgdl = toMgdl(snapshot)

        let t = LAAppGroupSettings.thresholdsMgdl()
        let low = t.low
        let high = t.high

        if mgdl < low {
            return Color(uiColor: UIColor.systemRed)
        } else if mgdl > high {
            return Color(uiColor: UIColor.systemOrange)
        } else {
            return Color(uiColor: UIColor.systemGreen)
        }
    }

    private static func toMgdl(_ snapshot: GlucoseSnapshot) -> Double {
        switch snapshot.unit {
        case .mgdl:
            return snapshot.glucose
        case .mmol:
            // Convert mmol/L → mg/dL for threshold comparison
            return GlucoseUnitConversion.convertGlucose(snapshot.glucose, from: .mmol, to: .mgdl)
        }
    }
}
