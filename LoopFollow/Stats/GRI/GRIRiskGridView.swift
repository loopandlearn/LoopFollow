// LoopFollow
// GRIRiskGridView.swift

import Charts
import SwiftUI

struct GRIRiskGridView: View {
    let hypoComponent: Double
    let hyperComponent: Double
    let gri: Double

    private enum Zone: String, CaseIterable, Plottable {
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
        case e = "E"

        var color: Color {
            switch self {
            case .a: return .green.opacity(0.3)
            case .b: return .yellow.opacity(0.3)
            case .c: return .orange.opacity(0.3)
            case .d: return .red.opacity(0.3)
            case .e: return .red.opacity(0.5)
            }
        }
    }

    private struct GridPoint: Identifiable {
        let hypo: Double
        let hyper: Double
        let zone: Zone
        var id: String { "\(hypo)-\(hyper)" }
    }

    private var gridPoints: [GridPoint] {
        var points: [GridPoint] = []
        let step = 0.5
        for hypo in stride(from: 0.0, through: 30.0, by: step) {
            for hyper in stride(from: 0.0, through: 60.0, by: step) {
                let griValue = (3.0 * hypo) + (1.6 * hyper)
                guard griValue <= 100 else { continue }

                let zone: Zone
                if griValue <= 20 {
                    zone = .a
                } else if griValue <= 40 {
                    zone = .b
                } else if griValue <= 60 {
                    zone = .c
                } else if griValue <= 80 {
                    zone = .d
                } else {
                    zone = .e
                }
                points.append(GridPoint(hypo: hypo, hyper: hyper, zone: zone))
            }
        }
        return points
    }

    var body: some View {
        Chart {
            ForEach(gridPoints) { point in
                PointMark(
                    x: .value("hypo", point.hypo),
                    y: .value("hyper", point.hyper)
                )
                .symbolSize(16)
                .foregroundStyle(by: .value("zone", point.zone))
            }

            PointMark(
                x: .value("hypo", hypoComponent),
                y: .value("hyper", hyperComponent)
            )
            .symbolSize(120)
            .foregroundStyle(Color(.label))
        }
        .chartForegroundStyleScale(
            domain: Zone.allCases,
            range: Zone.allCases.map(\.color)
        )
        .chartLegend(.hidden)
        .chartXScale(domain: 0 ... 30)
        .chartYScale(domain: 0 ... 60)
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .background(Color(.systemBackground))
    }
}
