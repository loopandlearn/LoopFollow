// LoopFollow
// BGChartView.swift

import Charts
import SwiftUI
import WatchKit

struct BGChartView: View {
    let bgHistory: [BGReading]
    let loopStatus: LoopStatus?
    let treatments: [Treatment]
    let tempTargetEntries: [TempTargetEntry]
    let overrideEntries: [OverrideEntry]
    let config: WatchConfig
    @Binding var timeOffset: Double
    @State private var lastHapticOffset: Double = 0
    @Binding var zoomHours: Double
    /// Treatment display: 0 = off, 1 = dots only, 2 = dots + labels
    @AppStorage("treatmentLevel") private var treatmentLevel: Int = 2

    private var treatmentFontSize: CGFloat {
        switch zoomHours {
        case ...0.5: return 10
        case ...1: return 8
        default: return 6
        }
    }
    private var treatmentSymbolSize: CGFloat { CGFloat(30.0 * min(1.6, max(0.7, 2.0 / zoomHours))) }
    private var showTreatmentLabels: Bool { treatmentLevel >= 2 }
    @FocusState private var chartFocused: Bool

    // timeOffset is in units of 5 minutes (1 BG reading), snapped to integers
    private var snappedOffset: Double {
        timeOffset.rounded()
    }

    private var visibleStart: Date {
        Date().addingTimeInterval(-zoomHours * 3600 + snappedOffset * 300)
    }

    private var visibleEnd: Date {
        Date().addingTimeInterval(snappedOffset * 300)
    }

    private var centerTime: Date {
        visibleStart.addingTimeInterval(visibleEnd.timeIntervalSince(visibleStart) * 0.7)
    }

    // Pre-filtered data for visible window only (with small margin)
    private var visibleBG: [BGReading] {
        let margin: TimeInterval = 600 // 10-min margin
        let start = visibleStart.addingTimeInterval(-margin)
        let end = visibleEnd.addingTimeInterval(margin)
        return bgHistory.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    private var visibleTreatments: [Treatment] {
        let margin: TimeInterval = 600
        let start = visibleStart.addingTimeInterval(-margin)
        let end = visibleEnd.addingTimeInterval(margin)
        return treatments.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    private var visibleOverrides: [OverrideEntry] {
        return overrideEntries.filter { $0.endDate >= visibleStart && $0.startDate <= visibleEnd }
    }

    private var visibleTempTargets: [TempTargetEntry] {
        return tempTargetEntries.filter { $0.endDate >= visibleStart && $0.startDate <= visibleEnd }
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

    /// Find the closest BG value at a given timestamp, offset slightly above for treatment dots
    private func bgValueAbove(timestamp: Date) -> Double {
        let closest = visibleBG.min(by: {
            abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp))
        })
        let baseBG: Double
        if let closest = closest, abs(closest.timestamp.timeIntervalSince(timestamp)) < 600 {
            baseBG = Double(closest.bgValue)
        } else {
            baseBG = 150
        }
        // Offset above by ~15 mg/dL so dots sit above the BG point
        return convertBG(baseBG + 15)
    }

    /// Find the closest BG value at a given timestamp, offset higher for carb dots to clear bolus markers
    private func bgValueAboveCarb(timestamp: Date) -> Double {
        let closest = visibleBG.min(by: {
            abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp))
        })
        let baseBG: Double
        if let closest = closest, abs(closest.timestamp.timeIntervalSince(timestamp)) < 600 {
            baseBG = Double(closest.bgValue)
        } else {
            baseBG = 150
        }
        // Offset above by ~40 mg/dL so carbs clear bolus triangles + their text
        return convertBG(baseBG + 75)
    }

    var body: some View {
        Chart {
            if treatmentLevel >= 1 {
                // Override ticker tape (purple band at bottom: 0-29 mg/dL)
                ForEach(visibleOverrides) { entry in
                    RectangleMark(
                        xStart: .value("Start", entry.startDate),
                        xEnd: .value("End", entry.endDate),
                        yStart: .value("Low", convertBG(0)),
                        yEnd: .value("High", convertBG(29))
                    )
                    .foregroundStyle(.purple.opacity(0.6))
                    .annotation(position: .overlay, alignment: .leading) {
                        Text(entry.name.isEmpty
                            ? (entry.percentage.map { String(format: "%.0f%%", $0) } ?? "Override")
                            : entry.name)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.leading, 2)
                    }
                }

                // Temp target ticker tape (green band: 31-60 mg/dL)
                ForEach(visibleTempTargets) { entry in
                    RectangleMark(
                        xStart: .value("Start", entry.startDate),
                        xEnd: .value("End", entry.endDate),
                        yStart: .value("Low", convertBG(31)),
                        yEnd: .value("High", convertBG(60))
                    )
                    .foregroundStyle(.green.opacity(0.6))
                    .annotation(position: .overlay, alignment: .leading) {
                        Text(entry.reason.isEmpty
                            ? String(format: "%.0f", entry.targetTop)
                            : entry.reason)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.leading, 2)
                    }
                }
            }

            // Midpoint inspection marker
            RuleMark(x: .value("Center", centerTime))
                .foregroundStyle(.white.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.5))

            // Prediction lines — detect OpenAPS by checking for populated prediction arrays
            if let status = loopStatus {
                let hasOpenAPSPredictions = status.ztPredictions != nil || status.iobPredictions != nil ||
                    status.cobPredictions != nil || status.uamPredictions != nil
                if status.isOpenAPS || hasOpenAPSPredictions {
                    predictionMarks(values: status.ztPredictions, start: status.predictionStart, color: Color(red: 0.443, green: 0.380, blue: 0.937), series: "ZT")
                    predictionMarks(values: status.iobPredictions, start: status.predictionStart, color: Color(red: 0.118, green: 0.588, blue: 0.988), series: "IOB")
                    predictionMarks(values: status.cobPredictions, start: status.predictionStart, color: Color(red: 1.0, green: 0.757, blue: 0.271), series: "COB")
                    predictionMarks(values: status.uamPredictions, start: status.predictionStart, color: Color(red: 1.0, green: 0.518, blue: 0.271), series: "UAM")
                } else {
                    predictionMarks(values: status.predictions, start: status.predictionStart, color: .purple, series: "Pred")
                }
            }

            if treatmentLevel >= 1 {
                // Bolus dots — blue upside-down triangles, offset above BG
                ForEach(visibleTreatments.filter { $0.type == .bolus || $0.type == .smb }) { treatment in
                    PointMark(
                        x: .value("Time", treatment.timestamp),
                        y: .value("BG", bgValueAbove(timestamp: treatment.timestamp))
                    )
                    .symbol {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: treatmentFontSize))
                            .foregroundColor(.blue)
                    }
                    .symbolSize(treatmentSymbolSize)
                    .foregroundStyle(.blue)
                    .annotation(position: .top, spacing: 1) {
                        if showTreatmentLabels {
                            Text(String(format: "%g", treatment.value))
                                .font(.system(size: treatmentFontSize, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Carb dots — yellow circles, offset above BG
                ForEach(visibleTreatments.filter { $0.type == .carbs }) { treatment in
                    PointMark(
                        x: .value("Time", treatment.timestamp),
                        y: .value("BG", bgValueAboveCarb(timestamp: treatment.timestamp))
                    )
                    .symbol(.circle)
                    .symbolSize(treatmentSymbolSize)
                    .foregroundStyle(.yellow)
                    .annotation(position: .top, spacing: 1) {
                        if showTreatmentLabels {
                            Text("\(Int(treatment.value))")
                                .font(.system(size: treatmentFontSize, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: visibleStart ... visibleEnd)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { _ in
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .font(.system(size: 8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 100, 200, 300].map { convertBG(Double($0)) }) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(config.units == "mmol/L" ? String(format: "%.0f", v) : String(format: "%.0f", v))
                            .font(.system(size: 7))
                    }
                }
            }
        }
        .chartBackground { proxy in
            sparklineOverlay(proxy: proxy)
        }
        .focusable()
        .focused($chartFocused)
        .digitalCrownRotation($timeOffset, from: -300, through: 22, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: false)
        .onAppear { chartFocused = true }
        .onChange(of: timeOffset) { newValue in
            let snapped = newValue.rounded()
            if snapped != lastHapticOffset {
                lastHapticOffset = snapped
                timeOffset = snapped
                WKInterfaceDevice.current().play(.click)
            }
        }
        .onTapGesture(count: 5) {
            treatmentLevel = (treatmentLevel + 1) % 3
            WKInterfaceDevice.current().play(.click)
        }
        .onTapGesture(count: 3) {
            // Triple-tap: zoom out (reverse cycle)
            switch zoomHours {
            case 6: zoomHours = 0.25
            case 0.25: zoomHours = 0.5
            case 0.5: zoomHours = 1
            case 1: zoomHours = 2
            case 2: zoomHours = 3
            default: zoomHours = 6
            }
        }
        .onTapGesture(count: 2) {
            // Double-tap: zoom in cycle 6h→3h→2h→1h→30m→15m→6h
            switch zoomHours {
            case 6: zoomHours = 3
            case 3: zoomHours = 2
            case 2: zoomHours = 1
            case 1: zoomHours = 0.5
            case 0.5: zoomHours = 0.25
            default: zoomHours = 6
            }
        }
    }

    private func pointColor(bgValue: Int) -> Color {
        return bgDynamicColor(Double(bgValue))
    }

    @ChartContentBuilder
    private func predictionMarks(values: [Double]?, start: Date?, color: Color, series: String) -> some ChartContent {
        if let values = values, let start = start, !values.isEmpty {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", start.addingTimeInterval(Double(index) * 300)),
                    y: .value("BG", convertBG(value)),
                    series: .value("Series", series)
                )
                .foregroundStyle(color.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    // MARK: - BG sparkline overlay (per-segment coloring)

    @ViewBuilder
    private func sparklineOverlay(proxy: ChartProxy) -> some View {
        // In .chartBackground, positions from proxy are relative to the plot area.
        GeometryReader { geo in
            let plotH = geo.size.height
            let sorted = visibleBG.sorted { $0.timestamp < $1.timestamp }

            Canvas { context, size in
                var screenPoints: [(point: CGPoint, bgValue: Int)] = []
                for reading in sorted {
                    guard let x = proxy.position(forX: reading.timestamp),
                          let y = proxy.position(forY: convertBG(Double(reading.bgValue))) else { continue }
                    screenPoints.append((CGPoint(x: x, y: y), reading.bgValue))
                }

                let pts = screenPoints.map(\.point)
                guard pts.count >= 2 else { return }

                for i in 0..<(pts.count - 1) {
                    let midBG = Double(screenPoints[i].bgValue + screenPoints[i + 1].bgValue) / 2.0
                    let segColor = bgDynamicColor(midBG)

                    let fillPath = segmentFillPath(points: pts, index: i, bottomY: size.height)
                    context.fill(
                        fillPath,
                        with: .linearGradient(
                            Gradient(colors: [segColor.opacity(0.60), segColor.opacity(0.05)]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    let strokePath = segmentStrokePath(points: pts, index: i)
                    context.stroke(
                        strokePath,
                        with: .color(segColor),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .frame(height: plotH)
        }
    }

    // MARK: - Catmull-Rom path builders (per-segment coloring)

    /// Single Catmull-Rom curve segment from points[index] to points[index+1].
    private func segmentStrokePath(points: [CGPoint], index i: Int) -> Path {
        Path { path in
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )

            path.move(to: p1)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
    }

    /// Fill area under a single Catmull-Rom segment, closed to bottomY.
    private func segmentFillPath(points: [CGPoint], index i: Int, bottomY: CGFloat) -> Path {
        Path { path in
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )

            path.move(to: p1)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
            path.addLine(to: CGPoint(x: p2.x, y: bottomY))
            path.addLine(to: CGPoint(x: p1.x, y: bottomY))
            path.closeSubpath()
        }
    }
}
