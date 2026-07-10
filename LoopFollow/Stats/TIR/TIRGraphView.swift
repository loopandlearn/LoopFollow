// LoopFollow
// TIRGraphView.swift

import Charts
import SwiftUI

struct TIRGraphView: View {
    let tirData: [TIRDataPoint]

    private enum Band: String, CaseIterable, Plottable {
        case veryLow = "Very Low"
        case low = "Low"
        case inRange = "In Range"
        case high = "High"
        case veryHigh = "Very High"

        var color: Color {
            switch self {
            case .veryLow: return .red.opacity(0.8)
            case .low: return .red.opacity(0.5)
            case .inRange: return .green.opacity(0.7)
            case .high: return .yellow.opacity(0.7)
            case .veryHigh: return .orange.opacity(0.7)
            }
        }
    }

    private struct Slice: Identifiable {
        let period: TIRPeriod
        let band: Band
        let value: Double
        var id: String { "\(period.rawValue)-\(band.rawValue)" }
    }

    private var slices: [Slice] {
        tirData.flatMap { point in
            [
                Slice(period: point.period, band: .veryLow, value: point.veryLow),
                Slice(period: point.period, band: .low, value: point.low),
                Slice(period: point.period, band: .inRange, value: point.inRange),
                Slice(period: point.period, band: .high, value: point.high),
                Slice(period: point.period, band: .veryHigh, value: point.veryHigh),
            ]
        }
    }

    var body: some View {
        Chart(slices) { slice in
            BarMark(
                x: .value("period", slice.period.rawValue),
                y: .value("pct", slice.value),
                width: .ratio(0.6)
            )
            .foregroundStyle(by: .value("band", slice.band))
        }
        .chartForegroundStyleScale(domain: Band.allCases, range: Band.allCases.map(\.color))
        .chartLegend(.hidden)
        .chartYScale(domain: 0 ... 100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5, 5]))
                AxisTick()
                AxisValueLabel {
                    if let pct = value.as(Int.self) {
                        Text("\(pct)%")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel()
            }
        }
        .allowsHitTesting(false)
        .background(Color(.systemBackground))
    }
}
