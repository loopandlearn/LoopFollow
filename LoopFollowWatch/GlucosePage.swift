// LoopFollow
// GlucosePage.swift

import Charts
import SwiftUI

/// Main page: one large BG value with trend and delta, IOB and COB, the running override, a two-hour sparkline,
/// and the remote commands in the bottom toolbar.
struct GlucosePage: View {
    let state: WatchState

    @EnvironmentObject private var session: WatchSession
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 2) {
                if let alarm = state.alarm {
                    AlarmBanner(alarm: alarm)
                }
                glucose(now: context.date)
                if !isLuminanceReduced {
                    details
                    overrideLine(now: context.date)
                    Sparkline(state: state, now: context.date)
                        .frame(minHeight: 36)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    age(now: context.date)
                }
                if !isLuminanceReduced, let remote = state.remote {
                    ToolbarItemGroup(placement: .bottomBar) {
                        RemoteToolbar(state: state, remote: remote)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func glucose(now: Date) -> some View {
        if let snapshot = state.snapshot {
            let isStale = now.timeIntervalSince(snapshot.updatedAt) >= WatchFormat.staleAfter
            VStack(spacing: -4) {
                // The arrow hangs off the number's trailing edge so the digits, and the delta under them, stay centered.
                Text(WatchFormat.glucose(snapshot.glucose, unit: snapshot.unit))
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(WatchFormat.bgColor(snapshot.glucose, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl, colored: state.colorBGText))
                    .strikethrough(isStale, pattern: .solid, color: .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .overlay(alignment: .trailing) {
                        Text(WatchFormat.trendArrow(snapshot.trend))
                            .font(.system(size: 28, weight: .black))
                            .fixedSize()
                            .alignmentGuide(.trailing) { $0[.leading] - 4 }
                    }
                    .padding(.horizontal, 34)
                Text(WatchFormat.delta(snapshot.delta, unit: snapshot.unit))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
        } else {
            Text("No BG data")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    /// Age of the reading, with a marker while the watch fetches on its own or cannot reach the phone.
    @ViewBuilder
    private func age(now: Date) -> some View {
        HStack(spacing: 2) {
            if state.source == .watch {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Fetched by the watch")
            } else if !session.isReachable {
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("iPhone not reachable")
            }
            if let snapshot = state.snapshot {
                Text(WatchFormat.minutesAgo(snapshot.updatedAt, now: now))
                    .foregroundStyle(now.timeIntervalSince(snapshot.updatedAt) >= WatchFormat.staleAfter ? .red : .secondary)
            }
        }
        .font(.footnote)
    }

    @ViewBuilder
    private var details: some View {
        if let snapshot = state.snapshot {
            if snapshot.isNotLooping {
                Label("Not looping", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if snapshot.iob != nil || snapshot.cob != nil {
                HStack(spacing: 12) {
                    if let iob = snapshot.iob {
                        Text("\(Image(systemName: "syringe")) \(WatchFormat.iob(iob))")
                            .accessibilityLabel("Insulin on board \(WatchFormat.iob(iob))")
                    }
                    if let cob = snapshot.cob {
                        Text("\(Image(systemName: "fork.knife")) \(WatchFormat.cob(cob))")
                            .accessibilityLabel("Carbs on board \(WatchFormat.cob(cob))")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
    }

    /// The running override's name and insulin needs, in the green of the overrides button and chart band.
    @ViewBuilder
    private func overrideLine(now: Date) -> some View {
        let active = state.activeOverride(at: now)
        // The phone's periods end on time; the watch's own fetch only has the snapshot's name.
        if let name = state.overrides == nil ? state.snapshot?.override : active?.name {
            let percent = active?.percent.map { "  ·  \($0) %" } ?? ""
            Text("\(Image(systemName: "slider.horizontal.3")) \(name)\(percent)")
                .font(.footnote)
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("Override \(name)\(active?.percent.map { ", insulin needs \($0) percent" } ?? "")")
        }
    }
}

/// Override, treatments and temp target, as in Apple's bottom-toolbar pattern.
private struct RemoteToolbar: View {
    let state: WatchState
    let remote: WatchRemoteConfig
    @EnvironmentObject private var session: WatchSession
    @EnvironmentObject private var navigator: WatchNavigator

    var body: some View {
        Button {
            navigator.push(.overrides)
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .tint(state.snapshot?.override != nil ? .green : nil)
        .accessibilityLabel("Overrides")
        .disabled(!session.canSendCommands)

        Button {
            navigator.push(.treatments)
        } label: {
            Image(systemName: "plus")
        }
        .tint(.blue)
        .accessibilityLabel("Meal or bolus")
        .disabled(!session.canSendCommands)

        if remote.kind == .trio {
            Button {
                navigator.push(.tempTargets)
            } label: {
                Image(systemName: "scope")
            }
            .tint(state.snapshot?.tempTargetMgdl != nil ? .green : nil)
            .accessibilityLabel("Temp Target")
            .disabled(!session.canSendCommands)
        } else {
            // Holds the trailing slot so + stays centered.
            Button {} label: {
                Image(systemName: "scope")
            }
            .hidden()
            .accessibilityHidden(true)
        }
    }
}

/// The last two hours in range colors, without axes, scaled to the readings and the range lines.
struct Sparkline: View {
    let state: WatchState
    let now: Date

    var body: some View {
        let start = now.addingTimeInterval(-2 * 3600)
        let readings = state.readings.filter { $0.date >= start }
        let values = readings.map(\.v)
        let bottom = min(values.min() ?? state.lowMgdl, state.lowMgdl) - 10
        let top = max(values.max() ?? state.highMgdl, state.highMgdl) + 10
        Chart {
            RuleMark(y: .value("High", state.highMgdl))
                .foregroundStyle(Color.yellow.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            RuleMark(y: .value("Low", state.lowMgdl))
                .foregroundStyle(Color.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            ForEach(readings, id: \.t) { reading in
                PointMark(x: .value("Time", reading.date), y: .value("BG", reading.v))
                    .symbolSize(12)
                    .foregroundStyle(WatchFormat.bgColor(reading.v, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl))
            }
        }
        .chartXScale(domain: start ... now)
        .chartYScale(domain: bottom ... top)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }
}

/// Shown while an alarm is sounding on the phone.
struct AlarmBanner: View {
    let alarm: WatchAlarm
    @EnvironmentObject private var session: WatchSession
    @State private var isSending = false
    @State private var error: String?

    var body: some View {
        Button {
            Task {
                isSending = true
                let reply = await session.send(.snoozeAlarm)
                isSending = false
                error = reply.success ? nil : reply.message
            }
        } label: {
            HStack {
                Image(systemName: "bell.fill")
                VStack(alignment: .leading) {
                    Text(alarm.name)
                        .lineLimit(1)
                    Text(isSending ? "Snoozing…" : "Tap to snooze")
                        .font(.caption2)
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isSending)
        .alert("Snooze failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }
}
