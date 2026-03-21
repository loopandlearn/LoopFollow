// LoopFollow
// TIRView.swift

import SwiftUI

struct TIRView: View {
    @ObservedObject var viewModel: TIRViewModel

    var body: some View {
        Button(action: {
            viewModel.toggleTIRMode()
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(viewModel.showTITR ? "Time in Tight Range" : "Time in Range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let inRangeValue = viewModel.tirData.first(where: { $0.period == .average })?.inRange {
                            Text(formatRange(inRangeValue))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !viewModel.tirData.isEmpty {
                        TIRGraphView(tirData: viewModel.tirData)
                            .frame(height: 250)
                            .allowsHitTesting(false)
                            .clipped()

                        VStack(alignment: .leading, spacing: 8) {
                            if let average = viewModel.tirData.first(where: { $0.period == .average }) {
                                Text("Cutoffs in \(UnitSettingsStore.shared.glucoseUnit.rawValue)")
                                    .foregroundColor(.secondary)

                                TIRLegendItem(
                                    color: .orange,
                                    label: "Very High (\(veryHighCutoffText))",
                                    percentage: average.veryHigh
                                )
                                TIRLegendItem(
                                    color: .yellow,
                                    label: "High (\(highCutoffText))",
                                    percentage: average.high
                                )
                                TIRLegendItem(
                                    color: .green,
                                    label: "In Range (\(inRangeCutoffText))",
                                    percentage: average.inRange
                                )
                                TIRLegendItem(
                                    color: .red.opacity(0.5),
                                    label: "Low (\(lowCutoffText))",
                                    percentage: average.low
                                )
                                TIRLegendItem(
                                    color: .red.opacity(0.8),
                                    label: "Very Low (\(veryLowCutoffText))",
                                    percentage: average.veryLow
                                )
                            }
                        }
                        .font(.caption2)
                    } else {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: 250)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(8)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatRange(_: Double) -> String {
        let glucoseUnit = UnitSettingsStore.shared.glucoseUnit
        let lowThreshold: Double
        let highThreshold: Double

        if glucoseUnit == .mgdL {
            lowThreshold = 70.0
            highThreshold = viewModel.showTITR ? 140.0 : 180.0
        } else {
            lowThreshold = 3.9
            highThreshold = viewModel.showTITR ? 7.8 : 10.0
        }

        return String(format: "%.1f – %.1f %@", lowThreshold, highThreshold, glucoseUnit.rawValue)
    }

    private var veryLowCutoffText: String {
        "< \(formatThreshold(veryLowThreshold))"
    }

    private var lowCutoffText: String {
        "\(formatThreshold(veryLowThreshold))–<\(formatThreshold(lowThreshold))"
    }

    private var inRangeCutoffText: String {
        "\(formatThreshold(lowThreshold))–\(formatThreshold(highThreshold))"
    }

    private var highCutoffText: String {
        ">\(formatThreshold(highThreshold))–\(formatThreshold(veryHighThreshold))"
    }

    private var veryHighCutoffText: String {
        "> \(formatThreshold(veryHighThreshold))"
    }

    private var lowThreshold: Double {
        UnitSettingsStore.shared.glucoseUnit == .mgdL ? 70.0 : 3.9
    }

    private var highThreshold: Double {
        if UnitSettingsStore.shared.glucoseUnit == .mgdL {
            return viewModel.showTITR ? 140.0 : 180.0
        }
        return viewModel.showTITR ? 7.8 : 10.0
    }

    private var veryLowThreshold: Double {
        UnitSettingsStore.shared.glucoseUnit == .mgdL ? 54.0 : 3.0
    }

    private var veryHighThreshold: Double {
        UnitSettingsStore.shared.glucoseUnit == .mgdL ? 250.0 : 13.9
    }

    private func formatThreshold(_ value: Double) -> String {
        if UnitSettingsStore.shared.glucoseUnit == .mgdL {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

struct TIRLegendItem: View {
    let color: Color
    let label: String
    let percentage: Double

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 16)
            Text(String(format: "%.1f%%", percentage))
                .foregroundColor(.primary)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
