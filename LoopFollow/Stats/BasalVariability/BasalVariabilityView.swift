// LoopFollow
// BasalVariabilityView.swift

import SwiftUI

struct BasalVariabilityView: View {
    @ObservedObject var viewModel: BasalVariabilityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Basal Variability")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let avg = viewModel.data.first(where: { $0.period == .average }) {
                    Text(String(format: "%.1f%% at plan", avg.atPlanned))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !viewModel.data.isEmpty {
                BasalVariabilityGraphView(data: viewModel.data)
                    .frame(height: 250)
                    .allowsHitTesting(false)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    if let avg = viewModel.data.first(where: { $0.period == .average }) {
                        Text("Actual as % of planned basal")
                            .foregroundColor(.secondary)

                        BasalVariabilityLegendItem(
                            color: .red.opacity(0.75),
                            label: "Very above (> 150%)",
                            percentage: avg.veryAbove
                        )
                        BasalVariabilityLegendItem(
                            color: .orange.opacity(0.65),
                            label: "Above (125–150%)",
                            percentage: avg.above
                        )
                        BasalVariabilityLegendItem(
                            color: .green.opacity(0.75),
                            label: "At planned (75–125%)",
                            percentage: avg.atPlanned
                        )
                        BasalVariabilityLegendItem(
                            color: Color(uiColor: .systemTeal).opacity(0.65),
                            label: "Below (50–75%)",
                            percentage: avg.below
                        )
                        BasalVariabilityLegendItem(
                            color: .blue.opacity(0.85),
                            label: "Very below (< 50%)",
                            percentage: avg.veryBelow
                        )
                    }
                }
                .font(.caption2)
            } else {
                Text("No basal data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 250)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BasalVariabilityLegendItem: View {
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
