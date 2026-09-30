// LoopFollow
// BGChartHistory.swift

import Foundation
import SwiftUI

/// Chart series built from DeviceStatusHistory: the panes under the main
/// chart, the smoothed BG line, the selection pill values and the forecast of
/// a selected reading.
enum BGChartHistory {
    /// Consecutive samples further apart than this are not joined by a line.
    static let maxJoinGap: TimeInterval = 15 * 60

    struct Point: Identifiable {
        let date: Date
        let value: Double
        /// Index of the unbroken run this point belongs to (see `maxJoinGap`).
        let segment: Int
        var id: TimeInterval { date.timeIntervalSince1970 }
    }

    enum PaneKind: Int, CaseIterable {
        case iob, cob, sensitivityRatio

        var title: String {
            switch self {
            case .iob: return "IOB"
            case .cob: return "COB"
            case .sensitivityRatio: return "Sens. Ratio"
            }
        }

        /// "lower–upper" with the unit once, for the main-graph legend.
        func rangeLabel(_ lower: Double, _ upper: Double) -> String {
            let lowerText: String
            switch self {
            case .iob: lowerText = Localizer.formatToLocalizedString(lower, maxFractionDigits: 1)
            case .cob: lowerText = Localizer.formatToLocalizedString(lower, maxFractionDigits: 0)
            case .sensitivityRatio: lowerText = Localizer.formatToLocalizedString(lower * 100, maxFractionDigits: 0)
            }
            return "\(lowerText)–\(axisLabel(upper))"
        }

        /// Label in the main-graph legend, where space is tight.
        var shortTitle: String {
            self == .sensitivityRatio ? "Ratio" : title
        }

        var color: Color {
            switch self {
            case .iob: return Color("Insulin")
            case .cob: return Color(.systemOrange)
            case .sensitivityRatio: return Color(.systemIndigo)
            }
        }

        var fillsArea: Bool {
            self == .iob || self == .cob
        }

        var isEnabled: Bool {
            switch self {
            case .iob: return Storage.shared.showIOBGraph.value
            case .cob: return Storage.shared.showCOBGraph.value
            case .sensitivityRatio: return Storage.shared.showSensitivityRatioGraph.value && Storage.shared.device.value != "Loop"
            }
        }

        func value(of sample: DeviceStatusHistorySample) -> Double? {
            switch self {
            case .iob: return sample.iob
            case .cob: return sample.cob
            case .sensitivityRatio: return sample.sensitivityRatio
            }
        }

        func format(_ value: Double) -> String {
            switch self {
            case .iob:
                return Localizer.formatToLocalizedString(value, maxFractionDigits: 2) + "U"
            case .cob:
                return Localizer.formatToLocalizedString(value, maxFractionDigits: 0) + "g"
            case .sensitivityRatio:
                return Localizer.formatToLocalizedString(value * 100, maxFractionDigits: 0) + "%"
            }
        }

        func axisLabel(_ value: Double) -> String {
            switch self {
            case .iob:
                return Localizer.formatToLocalizedString(value, maxFractionDigits: 1) + "U"
            default:
                return format(value)
            }
        }
    }

    struct Pane: Identifiable {
        let kind: PaneKind
        let points: [Point]
        let yDomain: ClosedRange<Double>
        /// Values labelled on the axis and drawn as grid lines.
        let ticks: [Double]
        /// Bottom of the area fill.
        let baseline: Double
        var id: Int { kind.rawValue }
    }

    /// History curves drawn as lines in the bottom band of the main chart. Each
    /// is scaled to its own range, which the legend states.
    struct Overlay {
        struct Series: Identifiable {
            let kind: PaneKind
            /// Negative IOB, drawn mirrored above the baseline.
            let isNegative: Bool
            let points: [Point]
            var id: String { "\(kind.rawValue)-\(isNegative)" }
            var color: Color { isNegative ? BGChartHistory.negativeIOBColor : kind.color }
        }

        struct LegendEntry: Identifiable {
            let kind: PaneKind
            /// Values at the bottom and top of the band.
            let range: String
            /// Set when negative IOB is drawn mirrored in its own color.
            let hasNegative: Bool
            var id: Int { kind.rawValue }
        }

        let series: [Series]
        /// Top of the band, in the main chart's mg/dL scale.
        let bandTop: Double
        let legend: [LegendEntry]
    }

    static let negativeIOBColor = Color(.systemPink)

    static func overlay(kinds: [PaneKind], samples: [DeviceStatusHistorySample], bandTop: Double) -> Overlay? {
        var series: [Overlay.Series] = []
        var legend: [Overlay.LegendEntry] = []

        for kind in kinds {
            let points = points(from: samples, value: kind.value(of:))
            guard let minValue = points.map(\.value).min(),
                  let maxValue = points.map(\.value).max()
            else { continue }

            if kind == .iob {
                // Magnitude scale: negative IOB is mirrored upward in its own color.
                let magnitude = max(abs(minValue), maxValue, 1).rounded(.up)
                let (positive, negative) = splitAtZero(points)
                series.append(.init(kind: kind, isNegative: false, points: positive.map { scaled($0, abs($0.value) / magnitude * bandTop) }))
                if !negative.isEmpty {
                    series.append(.init(kind: kind, isNegative: true, points: negative.map { scaled($0, abs($0.value) / magnitude * bandTop) }))
                }
                let range = negative.isEmpty ? kind.rangeLabel(0, magnitude) : "±\(kind.axisLabel(magnitude))"
                legend.append(.init(kind: kind, range: range, hasNegative: !negative.isEmpty))
                continue
            }

            let lower: Double
            let upper: Double
            switch kind {
            case .cob:
                lower = 0
                upper = max(10, (maxValue / 10).rounded(.up) * 10)
            case .sensitivityRatio:
                // Same range as the ratio graph, so a flat curve sits mid-band.
                lower = min(minValue, 0.9)
                upper = max(maxValue, 1.1)
            case .iob:
                continue
            }
            let span = max(upper - lower, .ulpOfOne)
            series.append(.init(kind: kind, isNegative: false, points: points.map { scaled($0, ($0.value - lower) / span * bandTop) }))
            legend.append(.init(kind: kind, range: kind.rangeLabel(lower, upper), hasNegative: false))
        }

        guard !series.isEmpty else { return nil }
        return Overlay(series: series, bandTop: bandTop, legend: legend)
    }

    private static func scaled(_ point: Point, _ value: Double) -> Point {
        Point(date: point.date, value: value, segment: point.segment)
    }

    /// Splits a curve into its positive and negative runs. A zero crossing ends
    /// one run and starts the other at the interpolated crossing time, so both
    /// meet the baseline there.
    static func splitAtZero(_ points: [Point]) -> (positive: [Point], negative: [Point]) {
        var positive: [Point] = []
        var negative: [Point] = []
        var segment = 0
        var previous: Point?
        for point in points {
            if let prev = previous {
                if prev.segment != point.segment {
                    segment += 1
                } else if prev.value * point.value < 0 {
                    let fraction = abs(prev.value) / (abs(prev.value) + abs(point.value))
                    let crossing = prev.date.addingTimeInterval(point.date.timeIntervalSince(prev.date) * fraction)
                    let zeroEnd = Point(date: crossing, value: 0, segment: segment)
                    if prev.value < 0 { negative.append(zeroEnd) } else { positive.append(zeroEnd) }
                    segment += 1
                    let zeroStart = Point(date: crossing, value: 0, segment: segment)
                    if point.value < 0 { negative.append(zeroStart) } else { positive.append(zeroStart) }
                } else if prev.value < 0, point.value == 0 {
                    // A reading of exactly zero belongs to the positive run; the
                    // negative run ends on it.
                    negative.append(Point(date: point.date, value: 0, segment: segment))
                    segment += 1
                } else if prev.value == 0, point.value < 0 {
                    segment += 1
                    negative.append(Point(date: prev.date, value: 0, segment: segment))
                }
            }
            let run = Point(date: point.date, value: point.value, segment: segment)
            if point.value < 0 { negative.append(run) } else { positive.append(run) }
            previous = point
        }
        return (positive, negative)
    }

    struct ForecastCurve: Identifiable {
        let name: String
        let color: Color
        let points: [(date: Date, value: Double)]
        var id: String { name }
    }

    struct Forecast {
        let curves: [ForecastCurve]
        /// Min/max envelope across the curves when the cone style is selected.
        let cone: [(date: Date, yMin: Double, yMax: Double)]
    }

    // MARK: - Building

    /// Splits the samples carrying a value into points, breaking the line at gaps.
    static func points(
        from samples: [DeviceStatusHistorySample],
        value: (DeviceStatusHistorySample) -> Double?
    ) -> [Point] {
        var points: [Point] = []
        var segment = 0
        var previousDate: TimeInterval?
        for sample in samples {
            guard let v = value(sample) else { continue }
            if let previousDate, sample.date - previousDate > maxJoinGap {
                segment += 1
            }
            points.append(Point(date: Date(timeIntervalSince1970: sample.date), value: v, segment: segment))
            previousDate = sample.date
        }
        return points
    }

    static func pane(kind: PaneKind, samples: [DeviceStatusHistorySample]) -> Pane? {
        let points = points(from: samples, value: kind.value(of:))
        guard let minValue = points.map(\.value).min(),
              let maxValue = points.map(\.value).max()
        else { return nil }

        let lower: Double
        let upper: Double
        var ticks: [Double]
        switch kind {
        case .iob:
            lower = min(0, minValue)
            upper = max(1, maxValue.rounded(.up))
            ticks = [0, upper]
        case .cob:
            lower = 0
            upper = max(10, (maxValue / 10).rounded(.up) * 10)
            ticks = [0, upper]
        case .sensitivityRatio:
            lower = min(minValue, 0.9)
            upper = max(maxValue, 1.1)
            ticks = [1]
            if minValue < 0.95 { ticks.insert(minValue, at: 0) }
            if maxValue > 1.05 { ticks.append(maxValue) }
        }
        let pad = (upper - lower) * 0.08
        return Pane(
            kind: kind,
            points: points,
            yDomain: (lower - pad) ... (upper + pad),
            ticks: ticks,
            baseline: kind == .iob || kind == .cob ? 0 : lower - pad
        )
    }

    /// The forecast the loop made when it ran on the reading at `readingDate`,
    /// cut to the Hours of Prediction setting.
    static func forecast(forReadingAt readingDate: Date) -> Forecast? {
        guard let stored = DeviceStatusHistory.shared.cycle(forReadingAt: readingDate)?.forecast else { return nil }

        let count = Int(Storage.shared.predictionToLoad.value * 12) + 1
        guard count > 1 else { return nil }
        let minDisplay = Double(globalVariables.minDisplayGlucose)
        let maxDisplay = Double(globalVariables.maxDisplayGlucose)
        let step = DeviceStatusHistorySample.Forecast.step

        func curvePoints(_ values: [Int]) -> [(date: Date, value: Double)] {
            values.prefix(count).enumerated().map { index, value in
                (
                    date: Date(timeIntervalSince1970: stored.start + Double(index) * step),
                    value: min(max(Double(value), minDisplay), maxDisplay)
                )
            }
        }

        if let main = stored.curves[DeviceStatusHistorySample.Forecast.loopCurve] {
            return Forecast(curves: [ForecastCurve(name: "main", color: .purple, points: curvePoints(main))], cone: [])
        }

        let names = DeviceStatusHistorySample.Forecast.openAPSCurves.filter { stored.curves[$0] != nil }
        guard !names.isEmpty else { return nil }

        if Storage.shared.predictionDisplayType.value == .cone {
            let arrays = names.compactMap { stored.curves[$0] }
            let length = min(arrays.map(\.count).min() ?? 0, count)
            let cone = (0 ..< length).map { index in
                let values = arrays.map { Double($0[index]) }
                var yMin = max(values.min() ?? 0, minDisplay)
                var yMax = min(values.max() ?? 0, maxDisplay)
                // Same ±1 mg/dL minimum band as the live cone, so agreeing curves stay visible.
                if yMin == yMax {
                    yMin -= 1
                    yMax += 1
                }
                return (date: Date(timeIntervalSince1970: stored.start + Double(index) * step), yMin: yMin, yMax: yMax)
            }
            return Forecast(curves: [], cone: cone)
        }

        let curves = names.compactMap { name -> ForecastCurve? in
            guard let values = stored.curves[name] else { return nil }
            return ForecastCurve(name: name, color: color(forCurve: name), points: curvePoints(values))
        }
        return Forecast(curves: curves, cone: [])
    }

    /// Same colors as the live forecast lines.
    private static func color(forCurve name: String) -> Color {
        switch name {
        case "ZT": return Color("ZT")
        case "IOB": return Color("Insulin")
        case "COB": return Color(.systemOrange)
        case "UAM": return Color("UAM")
        default: return .purple
        }
    }
}
