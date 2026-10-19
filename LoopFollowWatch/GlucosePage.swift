// LoopFollow
// GlucosePage.swift

import SwiftUI

/// Main page: BG, trend and delta as on the phone's home screen, with the chart below.
struct GlucosePage: View {
    let state: WatchState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 2) {
                if let alarm = state.alarm {
                    AlarmBanner(alarm: alarm)
                }
                header(now: context.date)
                WatchChartView(state: state, now: context.date)
                footer
            }
        }
        .navigationTitle {
            if let snapshot = state.snapshot {
                Text(WatchFormat.minutesAgo(snapshot.updatedAt))
                    .foregroundStyle(snapshot.age >= WatchFormat.staleAfter ? .red : .secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func header(now: Date) -> some View {
        if let snapshot = state.snapshot {
            let isStale = now.timeIntervalSince(snapshot.updatedAt) >= WatchFormat.staleAfter
            HStack(alignment: .center, spacing: 6) {
                Text(WatchFormat.glucose(snapshot.glucose, unit: snapshot.unit))
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(WatchFormat.bgColor(snapshot.glucose, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl, colored: state.colorBGText))
                    .strikethrough(isStale, pattern: .solid, color: .red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text(WatchFormat.trendArrow(snapshot.trend))
                        .font(.system(size: 22, weight: .black))
                    Text(WatchFormat.delta(snapshot.delta, unit: snapshot.unit))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            if snapshot.isNotLooping {
                Label("Not looping", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } else {
            Text("No BG data")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let snapshot = state.snapshot, snapshot.iob != nil || snapshot.cob != nil {
            HStack {
                Text("IOB \(WatchFormat.iob(snapshot.iob))")
                Spacer()
                Text("COB \(WatchFormat.cob(snapshot.cob))")
            }
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
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
