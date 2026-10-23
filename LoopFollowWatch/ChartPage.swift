// LoopFollow
// ChartPage.swift

import SwiftUI
import WatchKit

/// The full chart on its own page. Tap the chart or the crown button to scrub back
/// in time with the Digital Crown; tap again to return to now. The button in the
/// other corner changes the time span. The override line under the chart follows the marker.
struct ChartPage: View {
    let state: WatchState

    @AppStorage("chartSpanHours") private var spanHours: Double = 3
    @State private var isScrubbing = false
    @State private var scrubSteps = 0.0
    @FocusState private var crownFocused: Bool

    /// The crown moves in five-minute steps, back to the start of the 24 hours the phone sends.
    private var maxSteps: Double { max(0, (24 - spanHours * 0.75) * 12) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 2) {
                WatchChartView(
                    state: state,
                    now: context.date,
                    spanHours: spanHours,
                    scrubOffset: isScrubbing ? scrubSteps * 300 : nil
                )
                // Keeps the axis labels clear of the page indicator.
                .padding(.trailing, 10)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggleScrubbing)
                // Below the chart, clear of the toolbar buttons that float over the top of the page.
                if isScrubbing {
                    scrubDetails(now: context.date)
                }
                if let override = state.activeOverride(at: isScrubbing ? markerDate(now: context.date) : context.date) {
                    OverrideLine(name: override.name, percent: override.percent)
                        .padding(.trailing, 10)
                }
            }
            .focusable(isScrubbing)
            .focused($crownFocused)
            // Focus can only move once the page has become focusable, so it follows the toggle rather than
            // being set in the same tap; otherwise the crown keeps paging instead of scrubbing.
            .onChange(of: isScrubbing) { _, scrubbing in
                crownFocused = scrubbing
            }
            .onChange(of: crownFocused) { _, focused in
                if !focused {
                    isScrubbing = false
                }
            }
            .digitalCrownRotation($scrubSteps, from: 0, through: maxSteps, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: toggleScrubbing) {
                    Image(systemName: CrownSymbol.increase)
                }
                .tint(isScrubbing ? .green : nil)
                .accessibilityLabel(isScrubbing ? "Stop scrubbing" : "Scrub with the Digital Crown")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("\(Int(spanHours)) h") {
                    let index = WatchChartView.spans.firstIndex(of: spanHours) ?? 1
                    spanHours = WatchChartView.spans[(index + 1) % WatchChartView.spans.count]
                    scrubSteps = min(scrubSteps, maxSteps)
                }
                .accessibilityLabel("Time span \(Int(spanHours)) hours")
            }
        }
    }

    private func toggleScrubbing() {
        isScrubbing.toggle()
        scrubSteps = 0
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
        .padding(.trailing, 10)
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
