// LoopFollow
// GRIView.swift

import SwiftUI

struct GRIView: View {
    @ObservedObject var viewModel: GRIViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GRI (Glucose Risk Index)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let gri = viewModel.gri {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", gri))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(griColor(gri))
                        Text(griZone(gri))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("---")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }

            if let hypo = viewModel.griHypoComponent, let hyper = viewModel.griHyperComponent {
                GRIRiskGridView(
                    hypoComponent: hypo,
                    hyperComponent: hyper,
                    gri: viewModel.gri ?? 0
                )
                .frame(height: 250)
                .allowsHitTesting(false)
                .clipped()
                HStack {
                    Text("Hypoglycemia Component (%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Hyperglycemia Component (%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    ZoneLegendItem(color: .green, label: "A (0-20)")
                    ZoneLegendItem(color: .yellow, label: "B (21-40)")
                    ZoneLegendItem(color: .orange, label: "C (41-60)")
                    ZoneLegendItem(color: .red, label: "D (61-80)")
                    ZoneLegendItem(color: .red.opacity(0.8), label: "E (81-100)")
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func griColor(_ gri: Double) -> Color {
        if gri <= 20 {
            return .green
        } else if gri <= 40 {
            return .yellow
        } else if gri <= 60 {
            return .orange
        } else if gri <= 80 {
            return .red
        } else {
            return .red.opacity(0.8)
        }
    }

    private func griZone(_ gri: Double) -> String {
        if gri <= 20 {
            return "Zone A"
        } else if gri <= 40 {
            return "Zone B"
        } else if gri <= 60 {
            return "Zone C"
        } else if gri <= 80 {
            return "Zone D"
        } else {
            return "Zone E"
        }
    }
}

struct ZoneLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}
