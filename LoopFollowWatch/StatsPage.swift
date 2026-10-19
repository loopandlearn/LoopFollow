// LoopFollow
// StatsPage.swift

import Charts
import SwiftUI

/// The statistics panel from under the phone's chart: the same pie and values.
struct StatsPage: View {
    let state: WatchState
    let stats: WatchStats

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Chart(slices, id: \.0) { slice in
                    SectorMark(angle: .value("share", slice.1))
                        .foregroundStyle(slice.2)
                }
                .chartLegend(.hidden)
                .frame(height: 70)
                .accessibilityHidden(true)

                Grid(horizontalSpacing: 4, verticalSpacing: 6) {
                    GridRow {
                        value("Low:", stats.lowPercent)
                        value("In Range:", stats.inRangePercent)
                        value("High:", stats.highPercent)
                    }
                    GridRow {
                        value("Avg BG:", stats.avgBG)
                        value(stats.estA1CTitle, stats.estA1C)
                        value(stats.stdDevTitle, stats.stdDev)
                    }
                }

                if state.source == .watch {
                    Text("From the iPhone at \(state.phoneBuiltAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            // Keeps the values clear of the page indicator.
            .padding(.trailing, 10)
        }
        .navigationTitle("Statistics")
    }

    /// Same colors as the phone's pie: red low, green in range, yellow high.
    private var slices: [(String, Double, Color)] {
        [
            ("low", max(stats.pieLow, 0.1), .red),
            ("range", max(stats.pieRange, 0.1), .green),
            ("high", max(stats.pieHigh, 0.1), .yellow),
        ]
    }

    private func value(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
    }
}
