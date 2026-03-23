// LoopFollow
// LoopFollowLiveActivity.swift

import ActivityKit
import SwiftUI
import WidgetKit

/// Builds the shared Dynamic Island content used by both widget variants.
private func makeDynamicIsland(context: ActivityViewContext<GlucoseLiveActivityAttributes>) -> DynamicIsland {
    DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
            Link(destination: URL(string: "loopfollow://la-tap")!) {
                DynamicIslandLeadingView(snapshot: context.state.snapshot)
                    .overlay(RenewalOverlayView(show: context.state.snapshot.showRenewalOverlay))
            }
            .id(context.state.seq)
        }
        DynamicIslandExpandedRegion(.trailing) {
            Link(destination: URL(string: "loopfollow://la-tap")!) {
                DynamicIslandTrailingView(snapshot: context.state.snapshot)
                    .overlay(RenewalOverlayView(show: context.state.snapshot.showRenewalOverlay))
            }
            .id(context.state.seq)
        }
        DynamicIslandExpandedRegion(.bottom) {
            Link(destination: URL(string: "loopfollow://la-tap")!) {
                DynamicIslandBottomView(snapshot: context.state.snapshot)
                    .overlay(RenewalOverlayView(show: context.state.snapshot.showRenewalOverlay, showText: true))
            }
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

/// Primary widget — Lock Screen + Dynamic Island.
/// On iOS 18+, uses LockScreenFamilyAdaptiveView so that if the system selects this widget
/// for a .small context (CarPlay/Watch), SmallFamilyView is shown correctly.
@available(iOS, introduced: 16.1, obsoleted: 18.0)
struct LoopFollowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseLiveActivityAttributes.self) { context in
            LockScreenLiveActivityView(state: context.state)
                .id(context.state.seq)
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(LAColors.backgroundTint(for: context.state.snapshot))
                .applyActivityContentMarginsFixIfAvailable()
                .widgetURL(URL(string: "loopfollow://la-tap")!)
        } dynamicIsland: { context in
            makeDynamicIsland(context: context)
        }
    }
}

/// Supplemental widget (iOS 18.0+) — handles ALL rendering contexts:
/// Lock Screen (via LockScreenFamilyAdaptiveView → LockScreenLiveActivityView),
/// CarPlay Dashboard and Watch Smart Stack (via LockScreenFamilyAdaptiveView → SmallFamilyView).
/// Registered exclusively on iOS 18+; LoopFollowLiveActivityWidget is not registered on iOS 18+.

@available(iOS 18.0, *)
struct LoopFollowLiveActivityWidgetWithCarPlay: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseLiveActivityAttributes.self) { context in
            LockScreenFamilyAdaptiveView(state: context.state)
                .id(context.state.seq)
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(LAColors.backgroundTint(for: context.state.snapshot))
                .applyActivityContentMarginsFixIfAvailable()
                .widgetURL(URL(string: "loopfollow://la-tap")!)
        } dynamicIsland: { context in
            makeDynamicIsland(context: context)
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Live Activity content margins helper

private extension View {
    @ViewBuilder
    func applyActivityContentMarginsFixIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            // Use the generic SwiftUI API available in iOS 17+ (no placement enum)
            contentMargins(Edge.Set.all, 0)
        } else {
            self
        }
    }
}

// MARK: - Family-adaptive wrapper (Lock Screen / CarPlay / Watch Smart Stack)

/// Reads the activityFamily environment value and routes to the appropriate layout.
/// - `.small` → CarPlay Dashboard & Watch Smart Stack: compact glucose-only view
/// - everything else → full lock screen layout with configurable grid
@available(iOS 18.0, *)
private struct LockScreenFamilyAdaptiveView: View {
    let state: GlucoseLiveActivityAttributes.ContentState

    @Environment(\.activityFamily) var activityFamily

    var body: some View {
        if activityFamily == .small {
            SmallFamilyView(snapshot: state.snapshot)
        } else {
            LockScreenLiveActivityView(state: state)
                .activitySystemActionForegroundColor(.white)
                .activityBackgroundTint(LAColors.backgroundTint(for: state.snapshot))
                .applyActivityContentMarginsFixIfAvailable()
                .widgetURL(URL(string: "loopfollow://la-tap")!)
        }
    }
}

/*
@available(iOS 18.0, *)
private struct SmallFamilyView: View {
    let snapshot: GlucoseSnapshot

    var body: some View {
        ZStack {
            Color.red
            Text("SMALL")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}
*/
// MARK: - Small family view (CarPlay Dashboard + Watch Smart Stack)

/// Compact view shown on CarPlay Dashboard (iOS 26+) and Apple Watch Smart Stack (watchOS 11+).
/// Hardcoded to glucose + trend arrow + delta + time since last reading.

@available(iOS 18.0, *)
private struct SmallFamilyView: View {
    let snapshot: GlucoseSnapshot

    private var unitLabel: String {
        switch snapshot.unit {
        case .mgdl: return "mg/dL"
        case .mmol: return "mmol/L"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: BG + trend arrow, delta with unit — colored by glucose threshold
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(LAFormat.glucose(snapshot))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(LAFormat.trendArrow(snapshot))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(LAColors.keyline(for: snapshot))
                Text("\(LAFormat.delta(snapshot)) \(unitLabel)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LAColors.keyline(for: snapshot).opacity(0.85))
            }
            Spacer()
            // Right: Projected BG with unit label
            VStack(alignment: .trailing, spacing: 2) {
                Text(LAFormat.projected(snapshot))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(unitLabel)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(10)
        .activityBackgroundTint(LAColors.backgroundTint(for: snapshot))
    }
}

// MARK: - Lock Screen Contract View

private struct LockScreenLiveActivityView: View {
    let state: GlucoseLiveActivityAttributes.ContentState

    var body: some View {
        let s = state.snapshot
        let slotConfig = LAAppGroupSettings.slots()

        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // LEFT: Glucose + trend arrow, delta below
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(LAFormat.glucose(s))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .allowsTightening(true)
                            .layoutPriority(3)

                        Text(LAFormat.trendArrow(s))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Text("Delta: \(LAFormat.delta(s))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(1)
                }
                .frame(minWidth: 168, maxWidth: 190, alignment: .leading)
                .layoutPriority(2)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // RIGHT: configurable 2×2 grid
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        SlotView(option: slotConfig[0], snapshot: s)
                        SlotView(option: slotConfig[1], snapshot: s)
                    }
                    HStack(spacing: 12) {
                        SlotView(option: slotConfig[2], snapshot: s)
                        SlotView(option: slotConfig[3], snapshot: s)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Footer: last update time
            Text("Last Update: \(LAFormat.updated(s))")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1),
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
            },
        )
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.gray.opacity(0.9))
                Text("Tap to update")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .opacity(state.snapshot.showRenewalOverlay ? 1 : 0),
        )
    }
}

/// Full-size gray overlay shown 30 minutes before the LA renewal deadline.
/// Applied to both the lock screen view and each expanded Dynamic Island region.
private struct RenewalOverlayView: View {
    let show: Bool
    var showText: Bool = false

    var body: some View {
        ZStack {
            Color.gray.opacity(0.9)
            if showText {
                Text("Tap to update")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .opacity(show ? 1 : 0)
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
        .frame(width: 60, alignment: .leading) // slightly tighter columns to free space for glucose
    }
}

/// Renders one configurable slot in the lock screen 2×2 grid.
/// Shows nothing (invisible placeholder) when the slot option is `.none`.
private struct SlotView: View {
    let option: LiveActivitySlotOption
    let snapshot: GlucoseSnapshot

    var body: some View {
        if option == .none {
            // Invisible spacer — preserves grid alignment
            Color.clear
                .frame(width: 60, height: 36)
        } else {
            MetricBlock(label: option.gridLabel, value: value(for: option))
        }
    }

    private func value(for option: LiveActivitySlotOption) -> String {
        switch option {
        case .none: ""
        case .delta: LAFormat.delta(snapshot)
        case .projectedBG: LAFormat.projected(snapshot)
        case .minMax: LAFormat.minMax(snapshot)
        case .iob: LAFormat.iob(snapshot)
        case .cob: LAFormat.cob(snapshot)
        case .recBolus: LAFormat.recBolus(snapshot)
        case .autosens: LAFormat.autosens(snapshot)
        case .tdd: LAFormat.tdd(snapshot)
        case .basal: LAFormat.basal(snapshot)
        case .pump: LAFormat.pump(snapshot)
        case .pumpBattery: LAFormat.pumpBattery(snapshot)
        case .battery: LAFormat.battery(snapshot)
        case .target: LAFormat.target(snapshot)
        case .isf: LAFormat.isf(snapshot)
        case .carbRatio: LAFormat.carbRatio(snapshot)
        case .sage: LAFormat.age(insertTime: snapshot.sageInsertTime)
        case .cage: LAFormat.age(insertTime: snapshot.cageInsertTime)
        case .iage: LAFormat.age(insertTime: snapshot.iageInsertTime)
        case .carbsToday: LAFormat.carbsToday(snapshot)
        case .override: LAFormat.override(snapshot)
        case .profile: LAFormat.profileName(snapshot)
        }
    }
}

// MARK: - Dynamic Island

private struct DynamicIslandLeadingView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            Text("⚠️ Not Looping")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1.0)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(LAFormat.glucose(snapshot))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    Text(LAFormat.trendArrow(snapshot))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(LAFormat.delta(snapshot))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Proj: \(LAFormat.projected(snapshot))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
}

private struct DynamicIslandTrailingView: View {
    let snapshot: GlucoseSnapshot
    var body: some View {
        if snapshot.isNotLooping {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 3) {
                Text("IOB \(LAFormat.iob(snapshot))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.95))
                Text("COB \(LAFormat.cob(snapshot))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.trailing, 6)
        }
    }
}

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
            Text("Updated at: \(LAFormat.updated(snapshot))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

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
            Text(LAFormat.delta(snapshot))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.95))
        }
    }
}

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
    // MARK: - NumberFormatters (locale-aware)

    private static let mgdlFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.locale = .current
        return nf
    }()

    private static let mmolFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        nf.locale = .current
        return nf
    }()

    private static func formatGlucoseValue(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl:
            return mgdlFormatter.string(from: NSNumber(value: round(mgdl))) ?? "\(Int(round(mgdl)))"
        case .mmol:
            let mmol = GlucoseConversion.toMmol(mgdl)
            return mmolFormatter.string(from: NSNumber(value: mmol)) ?? String(format: "%.1f", mmol)
        }
    }

    // MARK: Glucose

    static func glucose(_ s: GlucoseSnapshot) -> String {
        formatGlucoseValue(s.glucose, unit: s.unit)
    }

    static func delta(_ s: GlucoseSnapshot) -> String {
        switch s.unit {
        case .mgdl:
            let v = Int(round(s.delta))
            if v == 0 { return "0" }
            return v > 0 ? "+\(v)" : "\(v)"

        case .mmol:
            let mmol = GlucoseConversion.toMmol(s.delta)
            let d = (abs(mmol) < 0.05) ? 0.0 : mmol
            if d == 0 { return mmolFormatter.string(from: 0) ?? "0.0" }
            let formatted = mmolFormatter.string(from: NSNumber(value: abs(d))) ?? String(format: "%.1f", abs(d))
            return d > 0 ? "+\(formatted)" : "-\(formatted)"
        }
    }

    // MARK: Trend

    static func trendArrow(_ s: GlucoseSnapshot) -> String {
        switch s.trend {
        case .upFast: "↑↑"
        case .up: "↑"
        case .upSlight: "↗"
        case .flat: "→"
        case .downSlight: "↘︎"
        case .down: "↓"
        case .downFast: "↓↓"
        case .unknown: "–"
        }
    }

    // MARK: Secondary

    static func iob(_ s: GlucoseSnapshot) -> String {
        guard let v = s.iob else { return "—" }
        return String(format: "%.1f", v)
    }

    static func cob(_ s: GlucoseSnapshot) -> String {
        guard let v = s.cob else { return "—" }
        return String(Int(round(v)))
    }

    static func projected(_ s: GlucoseSnapshot) -> String {
        guard let v = s.projected else { return "—" }
        return formatGlucoseValue(v, unit: s.unit)
    }

    // MARK: Extended InfoType formatters

    private static let ageFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .positional
        f.allowedUnits = [.day, .hour]
        f.zeroFormattingBehavior = [.pad]
        return f
    }()

    /// Formats an insert-time epoch into "D:HH" age string. Returns "—" if time is 0.
    static func age(insertTime: TimeInterval) -> String {
        guard insertTime > 0 else { return "—" }
        let secondsAgo = Date().timeIntervalSince1970 - insertTime
        return ageFormatter.string(from: secondsAgo) ?? "—"
    }

    static func recBolus(_ s: GlucoseSnapshot) -> String {
        guard let v = s.recBolus else { return "—" }
        return String(format: "%.2fU", v)
    }

    static func autosens(_ s: GlucoseSnapshot) -> String {
        guard let v = s.autosens else { return "—" }
        return String(format: "%.0f%%", v * 100)
    }

    static func tdd(_ s: GlucoseSnapshot) -> String {
        guard let v = s.tdd else { return "—" }
        return String(format: "%.1fU", v)
    }

    static func basal(_ s: GlucoseSnapshot) -> String {
        s.basalRate.isEmpty ? "—" : s.basalRate
    }

    static func pump(_ s: GlucoseSnapshot) -> String {
        guard let v = s.pumpReservoirU else { return "50+U" }
        return "\(Int(round(v)))U"
    }

    static func pumpBattery(_ s: GlucoseSnapshot) -> String {
        guard let v = s.pumpBattery else { return "—" }
        return String(format: "%.0f%%", v)
    }

    static func battery(_ s: GlucoseSnapshot) -> String {
        guard let v = s.battery else { return "—" }
        return String(format: "%.0f%%", v)
    }

    static func target(_ s: GlucoseSnapshot) -> String {
        guard let low = s.targetLowMgdl, low > 0 else { return "—" }
        let lowStr = formatGlucoseValue(low, unit: s.unit)
        if let high = s.targetHighMgdl, high > 0, abs(high - low) > 0.5 {
            return "\(lowStr)-\(formatGlucoseValue(high, unit: s.unit))"
        }
        return lowStr
    }

    static func isf(_ s: GlucoseSnapshot) -> String {
        guard let v = s.isfMgdlPerU, v > 0 else { return "—" }
        return formatGlucoseValue(v, unit: s.unit)
    }

    static func carbRatio(_ s: GlucoseSnapshot) -> String {
        guard let v = s.carbRatio, v > 0 else { return "—" }
        return String(format: "%.0fg", v)
    }

    static func carbsToday(_ s: GlucoseSnapshot) -> String {
        guard let v = s.carbsToday else { return "—" }
        return "\(Int(round(v)))g"
    }

    static func minMax(_ s: GlucoseSnapshot) -> String {
        guard let mn = s.minBgMgdl, let mx = s.maxBgMgdl else { return "—" }
        return "\(formatGlucoseValue(mn, unit: s.unit))/\(formatGlucoseValue(mx, unit: s.unit))"
    }

    static func override(_ s: GlucoseSnapshot) -> String {
        s.override ?? "—"
    }

    static func profileName(_ s: GlucoseSnapshot) -> String {
        s.profileName ?? "—"
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
        let mgdl = snapshot.glucose

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
            return Color(uiColor: UIColor.systemGreen).opacity(0.36)
        }
    }

    static func keyline(for snapshot: GlucoseSnapshot) -> Color {
        let mgdl = snapshot.glucose

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
}
