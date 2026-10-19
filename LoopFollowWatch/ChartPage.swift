// LoopFollow
// ChartPage.swift

import SwiftUI
import WatchKit

/// The full chart on its own page. Tap the chart to scrub back in time with the
/// Digital Crown; tap again to return to now. The button in the corner changes
/// the time span.
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
                if isScrubbing {
                    scrubHeader(now: context.date)
                }
                WatchChartView(
                    state: state,
                    now: context.date,
                    spanHours: spanHours,
                    scrubOffset: isScrubbing ? scrubSteps * 300 : nil
                )
                // Keeps the axis labels clear of the page indicator.
                .padding(.trailing, 10)
                .contentShape(Rectangle())
                .onTapGesture {
                    isScrubbing.toggle()
                    scrubSteps = 0
                    crownFocused = isScrubbing
                }
            }
            .focusable(isScrubbing)
            .focused($crownFocused)
            .digitalCrownRotation($scrubSteps, from: 0, through: maxSteps, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        }
        .toolbar {
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

    /// Time and BG at the marker.
    private func scrubHeader(now: Date) -> some View {
        let marker = WatchChartView.markerDate(state: state, now: now, spanHours: spanHours, scrubOffset: scrubSteps * 300)
        let nearest = state.readings.min { abs($0.date.timeIntervalSince(marker)) < abs($1.date.timeIntervalSince(marker)) }
        let reading = nearest.flatMap { abs($0.date.timeIntervalSince(marker)) <= 450 ? $0 : nil }
        return HStack {
            Text(marker.formatted(date: .omitted, time: .shortened))
                .foregroundStyle(.secondary)
            Spacer()
            if let reading {
                Text(WatchFormat.glucose(reading.v, unit: state.snapshot?.unit ?? .mgdl))
                    .foregroundStyle(WatchFormat.bgColor(reading.v, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl))
            } else {
                Text("—")
            }
        }
        .font(.headline)
        .monospacedDigit()
    }
}
