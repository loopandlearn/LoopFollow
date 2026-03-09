// LoopFollow
// AGPView.swift

import SwiftUI

struct AGPView: View {
    @ObservedObject var viewModel: AGPViewModel

    var body: some View {
        if !viewModel.agpData.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ambulatory Glucose Profile (AGP)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                AGPGraphView(agpData: viewModel.agpData)
                    .frame(height: 200)
                    .allowsHitTesting(false)
                    .clipped()

                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .gray.opacity(0.6), label: "5th-95th")
                    LegendItem(color: .blue.opacity(0.7), label: "25th-75th")
                    LegendItem(color: .blue, label: "Median")
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}
