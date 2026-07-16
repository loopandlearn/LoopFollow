// LoopFollow
// AGPGraphView.swift

import Charts
import SwiftUI

struct AGPGraphView: View {
    let agpData: [AGPDataPoint]

    private enum Percentile: String, CaseIterable, Plottable {
        case p5 = "5th"
        case p25 = "25th"
        case median = "Median"
        case p75 = "75th"
        case p95 = "95th"

        var color: Color {
            switch self {
            case .p5, .p95: return Color(.systemGray).opacity(0.6)
            case .p25, .p75: return Color(.systemBlue).opacity(0.7)
            case .median: return Color(.systemBlue)
            }
        }

        var lineWidth: CGFloat {
            self == .median ? 3 : 1.5
        }
    }

    private struct Point: Identifiable {
        let percentile: Percentile
        let hour: Double
        let value: Double
        var id: String { "\(percentile.rawValue)-\(hour)" }
    }

    private var points: [Point] {
        let sortedData = agpData.sorted { $0.timeOfDay < $1.timeOfDay }
        return sortedData.flatMap { dp -> [Point] in
            let hour = Double(dp.timeOfDay) / 60.0
            return [
                Point(percentile: .p5, hour: hour, value: dp.p5),
                Point(percentile: .p25, hour: hour, value: dp.p25),
                Point(percentile: .median, hour: hour, value: dp.p50),
                Point(percentile: .p75, hour: hour, value: dp.p75),
                Point(percentile: .p95, hour: hour, value: dp.p95),
            ]
        }
    }

    private var activeThresholds: (low: Double, high: Double) {
        UnitSettingsStore.shared.effectiveThresholds()
    }

    private var lowThresholdLabel: String {
        thresholdLabel(for: activeThresholds.low)
    }

    private var highThresholdLabel: String {
        thresholdLabel(for: activeThresholds.high)
    }

    private var plottedMinValue: Double {
        min(points.map(\.value).min() ?? activeThresholds.low, activeThresholds.low)
    }

    private var plottedMaxValue: Double {
        max(points.map(\.value).max() ?? activeThresholds.high, activeThresholds.high)
    }

    private var yDomain: ClosedRange<Double> {
        let span = max(plottedMaxValue - plottedMinValue, 1)
        let topPadding = max(span * 0.05, 1)
        return plottedMinValue ... (plottedMaxValue + topPadding)
    }

    private var yAxisEndpoints: [Double] {
        if abs(plottedMaxValue - plottedMinValue) < 0.0001 {
            return [plottedMinValue]
        }
        return [plottedMinValue, plottedMaxValue]
    }

    private func thresholdLabel(for mgdlValue: Double) -> String {
        let display = UnitSettingsStore.shared.convertMgdlToDisplay(mgdlValue)
        let digits = UnitSettingsStore.shared.glucoseUnit.fractionDigits
        return String(format: "%.*f", digits, display)
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("lowBoundary", activeThresholds.low))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .leading, alignment: .leading) {
                    Text(lowThresholdLabel)
                        .font(.caption2)
                }

            RuleMark(y: .value("highBoundary", activeThresholds.high))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .leading, alignment: .leading) {
                    Text(highThresholdLabel)
                        .font(.caption2)
                }

            ForEach(points) { point in
                LineMark(
                    x: .value("hour", point.hour),
                    y: .value("bg", point.value)
                )
                .foregroundStyle(by: .value("percentile", point.percentile))
                .lineStyle(StrokeStyle(lineWidth: point.percentile.lineWidth))
                .interpolationMethod(.linear)
            }
        }
        .chartForegroundStyleScale(
            domain: Percentile.allCases,
            range: Percentile.allCases.map(\.color)
        )
        .chartLegend(.hidden)
        .chartXScale(domain: 0 ... 24)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(position: .bottom, values: Array(stride(from: 0, through: 24, by: 3))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.label).opacity(0.3))
                AxisTick()
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour)")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisEndpoints) { value in
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(Localizer.toDisplayUnits(String(raw)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .background(Color(.systemBackground))
    }
}
