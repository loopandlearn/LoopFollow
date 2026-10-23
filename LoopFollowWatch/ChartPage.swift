// LoopFollow
// ChartPage.swift

import SwiftUI

/// The full chart on its own page. Tap the chart to open it for scrubbing with the Digital Crown.
/// The button in the corner changes the time span.
struct ChartPage: View {
    let state: WatchState

    @EnvironmentObject private var navigator: WatchNavigator
    @AppStorage("chartSpanHours") private var spanHours: Double = 3

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 2) {
                WatchChartView(state: state, now: context.date, spanHours: spanHours, scrubOffset: nil)
                    // Keeps the axis labels clear of the page indicator.
                    .padding(.trailing, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { navigator.push(.chartScrub) }
                if let override = state.activeOverride(at: context.date) {
                    OverrideLine(name: override.name, percent: override.percent)
                        .padding(.trailing, 10)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpanButton(spanHours: $spanHours)
            }
        }
    }
}

/// The chart on a screen of its own, where the Digital Crown moves the marker back in time.
/// The time, BG, carbs, insulin and override at the marker show below the chart. Tap the chart
/// or go back to leave; the crown then pages between the watch pages again.
struct ChartScrubView: View {
    let state: WatchState

    @Environment(\.dismiss) private var dismiss
    @AppStorage("chartSpanHours") private var spanHours: Double = 3
    @State private var scrubSteps = 0.0
    @FocusState private var crownFocused: Bool

    /// The crown moves in five-minute steps, back to the start of the 24 hours the phone sends.
    private var maxSteps: Double { max(0, (24 - spanHours * 0.75) * 12) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 2) {
                WatchChartView(state: state, now: context.date, spanHours: spanHours, scrubOffset: scrubSteps * 300)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                scrubDetails(now: context.date)
                if let override = state.activeOverride(at: markerDate(now: context.date)) {
                    OverrideLine(name: override.name, percent: override.percent)
                }
            }
            .focusable()
            .focused($crownFocused)
            .digitalCrownRotation($scrubSteps, from: 0, through: maxSteps, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        }
        .onAppear { crownFocused = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpanButton(spanHours: $spanHours)
            }
        }
        .onChange(of: spanHours) {
            scrubSteps = min(scrubSteps, maxSteps)
        }
    }

    /// Time, BG, carbs and insulin at the marker. Carbs and boluses count when they fall within the
    /// marker's five-minute crown step, so each entry shows at exactly one step.
    private func scrubDetails(now: Date) -> some View {
        let marker = markerDate(now: now)
        let nearest = state.readings.min { abs($0.date.timeIntervalSince(marker)) < abs($1.date.timeIntervalSince(marker)) }
        let reading = nearest.flatMap { abs($0.date.timeIntervalSince(marker)) <= 450 ? $0 : nil }
        let carbs = total(of: state.carbs, near: marker)
        let insulin = total(of: state.boluses, near: marker)
        return HStack(spacing: 8) {
            Text(marker.formatted(date: .omitted, time: .shortened))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                if let reading {
                    Circle()
                        .fill(WatchFormat.bgColor(reading.v, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl))
                        .frame(width: 7, height: 7)
                    Text(WatchFormat.glucose(reading.v, unit: state.snapshot?.unit ?? .mgdl))
                } else {
                    Text("—")
                }
            }
            if let carbs {
                Text("\(Image(systemName: "fork.knife")) \(WatchFormat.cob(carbs))")
                    .accessibilityLabel("Carbs \(WatchFormat.cob(carbs))")
            }
            if let insulin {
                Text("\(Image(systemName: "syringe")) \(WatchFormat.insulin(insulin)) U")
                    .accessibilityLabel("Bolus \(WatchFormat.insulin(insulin)) U")
            }
        }
        .font(.footnote)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func markerDate(now: Date) -> Date {
        WatchChartView.markerDate(state: state, now: now, spanHours: spanHours, scrubOffset: scrubSteps * 300)
    }

    /// Sum of the entries within half a crown step of the marker, or nil when there are none.
    private func total(of entries: [WatchReading], near marker: Date) -> Double? {
        let matching = entries.filter { abs($0.date.timeIntervalSince(marker)) < 150 }
        return matching.isEmpty ? nil : matching.reduce(0) { $0 + $1.v }
    }
}

/// Steps through the chart time spans.
private struct SpanButton: View {
    @Binding var spanHours: Double

    var body: some View {
        Button("\(Int(spanHours)) h") {
            let index = WatchChartView.spans.firstIndex(of: spanHours) ?? 1
            spanHours = WatchChartView.spans[(index + 1) % WatchChartView.spans.count]
        }
        .accessibilityLabel("Time span \(Int(spanHours)) hours")
    }
}
