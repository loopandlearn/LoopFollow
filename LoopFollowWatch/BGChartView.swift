// LoopFollow
// BGChartView.swift

import Charts
import SwiftUI
import WatchKit

struct BGChartView: View {
    let bgHistory: [BGReading]
    let loopStatus: LoopStatus?
    let config: WatchConfig
    @Binding var timeOffset: Double
    @State private var lastHapticOffset: Double = 0

    // timeOffset is in units of 5 minutes (1 BG reading), snapped to integers
    private var snappedOffset: Double {
        timeOffset.rounded()
    }

    private var visibleStart: Date {
        Date().addingTimeInterval(-3 * 3600 + snappedOffset * 300)
    }

    private var visibleEnd: Date {
        Date().addingTimeInterval(snappedOffset * 300)
    }

    private var yDomain: ClosedRange<Double> {
        if config.units == "mmol/L" {
            return 0 ... 16.7
        }
        return 0 ... 300
    }

    private func convertBG(_ mgdl: Double) -> Double {
        config.units == "mmol/L" ? mgdl * 0.0555 : mgdl
    }

    var body: some View {
        Chart {
            // Threshold lines
            RuleMark(y: .value("Low", convertBG(config.lowLine)))
                .foregroundStyle(.red.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
            RuleMark(y: .value("High", convertBG(config.highLine)))
                .foregroundStyle(.yellow.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 3]))

            // BG history points
            ForEach(bgHistory, id: \.timestamp) { reading in
                PointMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("BG", convertBG(Double(reading.bgValue)))
                )
                .symbolSize(12)
                .foregroundStyle(pointColor(bgValue: reading.bgValue))
            }

            // Prediction lines
            if let status = loopStatus {
                if status.isOpenAPS {
                    predictionMarks(values: status.ztPredictions, start: status.predictionStart, color: Color(red: 0.443, green: 0.380, blue: 0.937))
                    predictionMarks(values: status.iobPredictions, start: status.predictionStart, color: Color(red: 0.118, green: 0.588, blue: 0.988))
                    predictionMarks(values: status.cobPredictions, start: status.predictionStart, color: Color(red: 1.0, green: 0.757, blue: 0.271))
                    predictionMarks(values: status.uamPredictions, start: status.predictionStart, color: Color(red: 1.0, green: 0.518, blue: 0.271))
                } else {
                    predictionMarks(values: status.predictions, start: status.predictionStart, color: .purple)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: visibleStart ... visibleEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .font(.system(size: 8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 100, 200, 300].map { convertBG(Double($0)) }) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(config.units == "mmol/L" ? String(format: "%.0f", v) : String(format: "%.0f", v))
                            .font(.system(size: 7))
                    }
                }
            }
        }
        .focusable()
        .digitalCrownRotation($timeOffset, from: -300, through: 12, by: 1, sensitivity: .low, isHapticFeedbackEnabled: false)
        .onChange(of: timeOffset) { newValue in
            let snapped = newValue.rounded()
            if snapped != lastHapticOffset {
                lastHapticOffset = snapped
                timeOffset = snapped
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private func pointColor(bgValue: Int) -> Color {
        let bg = Double(bgValue)
        if bg <= config.lowLine { return .red }
        if bg >= config.highLine { return .yellow }
        return .green
    }

    @ChartContentBuilder
    private func predictionMarks(values: [Double]?, start: Date?, color: Color) -> some ChartContent {
        if let values = values, let start = start, !values.isEmpty {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", start.addingTimeInterval(Double(index) * 300)),
                    y: .value("BG", convertBG(value))
                )
                .foregroundStyle(color.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .interpolationMethod(.catmullRom)
            }
        }
    }
}
