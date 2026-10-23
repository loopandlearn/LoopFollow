// LoopFollow
// WatchChartView.swift

import Charts
import SwiftUI

/// BG chart in the phone's colors: readings colored by range, dashed low/high
/// lines, prediction lines or cone in their phone colors, boluses and carbs as markers,
/// and overrides as a green band along the top.
struct WatchChartView: View {
    let state: WatchState
    let now: Date
    let spanHours: Double
    /// How far back the chart is scrolled; nil when not scrubbing.
    var scrubOffset: TimeInterval?

    static let spans: [Double] = [1, 3, 6, 12, 24]

    private var unit: GlucoseSnapshot.Unit { state.snapshot?.unit ?? .mgdl }

    var body: some View {
        let window = visibleWindow
        let readings = state.readings.filter { window.contains($0.date) }
        let predictions = state.predictions.map { line in
            (line.kind, line.points.filter { window.contains($0.date) })
        }
        let cone = state.cone.filter { window.contains($0.date) }
        let overrides = (state.overrides ?? []).filter { $0.endDate > window.lowerBound && $0.startDate < window.upperBound }
        let top = yTop(readings: readings, predictions: predictions.flatMap(\.1) + cone.map { WatchReading(t: $0.t, v: $0.high) })

        Chart {
            RuleMark(y: .value("High", state.highMgdl))
                .foregroundStyle(Color.yellow.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            RuleMark(y: .value("Low", state.lowMgdl))
                .foregroundStyle(Color.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            RuleMark(x: .value("Now", now))
                .foregroundStyle(Color.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1))

            ForEach(cone, id: \.t) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Low", point.low),
                    yEnd: .value("High", min(point.high, top))
                )
                .foregroundStyle(Color.blue.opacity(0.4))
            }

            // A thin band along the top edge, like the override strip on the phone's chart.
            ForEach(overrides, id: \.start) { override in
                RectangleMark(
                    xStart: .value("Start", max(override.startDate, window.lowerBound)),
                    xEnd: .value("End", min(override.endDate, window.upperBound)),
                    y: .value("Override", top),
                    height: .fixed(4)
                )
                .foregroundStyle(Color.green.opacity(0.8))
            }

            if let marker = markerDate {
                RuleMark(x: .value("Marker", marker))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }

            ForEach(predictions, id: \.0) { kind, points in
                ForEach(points, id: \.t) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("BG", min(point.v, top)),
                        series: .value("Series", kind.rawValue)
                    )
                    .foregroundStyle(Self.color(for: kind))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }

            ForEach(readings, id: \.t) { reading in
                PointMark(
                    x: .value("Time", reading.date),
                    y: .value("BG", min(reading.v, top))
                )
                .symbolSize(spanHours <= 3 ? 14 : 6)
                .foregroundStyle(WatchFormat.bgColor(reading.v, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl))
            }

            ForEach(state.carbs.filter { window.contains($0.date) }, id: \.t) { carb in
                PointMark(
                    x: .value("Time", carb.date),
                    y: .value("BG", max(markerY(at: carb.date, top: top) - 30, 45))
                )
                .symbolSize(30)
                .foregroundStyle(Color.orange.opacity(0.85))
            }

            ForEach(state.boluses.filter { window.contains($0.date) }, id: \.t) { bolus in
                PointMark(
                    x: .value("Time", bolus.date),
                    y: .value("BG", markerY(at: bolus.date, top: top) + 30)
                )
                .symbol(.triangle)
                .symbolSize(24)
                .foregroundStyle(Color.blue.opacity(0.85))
            }
        }
        .chartXScale(domain: window.lowerBound ... window.upperBound)
        .chartYScale(domain: 39 ... top)
        .chartXAxis {
            AxisMarks(values: hourTicks(in: window)) { _ in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisValues(top: top)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let mgdl = value.as(Double.self) {
                        Text(WatchFormat.glucose(mgdl, unit: unit))
                    }
                }
            }
        }
        .accessibilityLabel("BG chart, last \(Int(spanHours)) hours.")
    }

    private var visibleWindow: ClosedRange<Date> {
        Self.window(state: state, now: now, spanHours: spanHours, scrubOffset: scrubOffset ?? 0)
    }

    private var markerDate: Date? {
        scrubOffset.map { Self.markerDate(state: state, now: now, spanHours: spanHours, scrubOffset: $0) }
    }

    /// The visible span ends a little after now so the prediction stays visible;
    /// while scrubbing it moves back by the scroll offset.
    static func window(state: WatchState, now: Date, spanHours: Double, scrubOffset: TimeInterval) -> ClosedRange<Date> {
        let span = spanHours * 3600
        let lookAhead = state.predictions.isEmpty && state.cone.isEmpty ? span * 0.05 : span * 0.25
        let end = now.addingTimeInterval(lookAhead - scrubOffset)
        return end.addingTimeInterval(-span) ... end
    }

    /// While scrubbing, the time the marker points at: three quarters across the chart.
    static func markerDate(state: WatchState, now: Date, spanHours: Double, scrubOffset: TimeInterval) -> Date {
        window(state: state, now: now, spanHours: spanHours, scrubOffset: scrubOffset).upperBound
            .addingTimeInterval(-spanHours * 3600 * 0.25)
    }

    /// Whole hours in the window, leaving out those too close to an edge for their label to fit.
    private func hourTicks(in window: ClosedRange<Date>) -> [Date] {
        let step = spanHours > 6 ? 6 : (spanHours > 3 ? 2 : 1)
        let margin = (window.upperBound.timeIntervalSince(window.lowerBound)) * 0.06
        let calendar = Calendar.current
        guard var tick = calendar.dateInterval(of: .hour, for: window.lowerBound)?.end else { return [] }
        var ticks: [Date] = []
        while tick < window.upperBound {
            let hour = calendar.component(.hour, from: tick)
            if hour % step == 0,
               tick.timeIntervalSince(window.lowerBound) > margin,
               window.upperBound.timeIntervalSince(tick) > margin
            {
                ticks.append(tick)
            }
            tick = tick.addingTimeInterval(3600)
        }
        return ticks
    }

    private func yTop(readings: [WatchReading], predictions: [WatchReading]) -> Double {
        let highest = max(readings.map(\.v).max() ?? 0, predictions.map(\.v).max() ?? 0)
        return min(max(250, highest + 20), 400)
    }

    private func yAxisValues(top: Double) -> [Double] {
        let steps: [Double] = unit == .mmol
            ? [72, 144, 216, 288, 360].filter { $0 < top }
            : [100, 200, 300].filter { $0 < top }
        return steps
    }

    /// Markers sit next to the BG reading closest in time: boluses above, carbs below, as on the phone.
    private func markerY(at date: Date, top: Double) -> Double {
        let nearest = state.readings.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        return min(nearest?.v ?? 100, top - 30)
    }

    static func color(for kind: WatchPredictionLine.Kind) -> Color {
        switch kind {
        case .loop: .purple
        case .zt: Color(red: 0.443, green: 0.380, blue: 0.937)
        case .iob: Color(red: 0.118, green: 0.588, blue: 0.988)
        case .cob: .orange
        case .uam: Color(red: 0.820, green: 0.169, blue: 0.969)
        }
    }
}
