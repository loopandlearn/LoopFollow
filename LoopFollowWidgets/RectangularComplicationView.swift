// LoopFollow
// RectangularComplicationView.swift

import SwiftUI
import WidgetKit

// MARK: - Public Complication View (used by Widget + future Live Activity)

/// Full-width sparkline with text stats overlaid on the left.
/// Graph fades in aggressively; line thickens and brightens from left to right.
struct BGComplicationContent: View {
    let data: WidgetData
    let displayDate: Date
    let useColor: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            // Full-width sparkline — aggressive left fade
            SparklineView(
                history: data.history,
                displayDate: displayDate
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.39),
                        .init(color: .white, location: 0.80),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Text overlay on the left
            StatsPanel(data: data, displayDate: displayDate)
                .padding(.leading, 0)
        }
        .padding(.horizontal, 0)
    }
}

/// Thin wrapper that reads `BGEntry` and the widget rendering mode, then delegates
/// to `BGComplicationContent`.
struct RectangularComplicationView: View {
    let entry: BGEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    private var useColor: Bool {
        renderingMode == .fullColor
    }

    var body: some View {
        if let data = entry.data {
            BGComplicationContent(
                data: data,
                displayDate: entry.displayDate,
                useColor: useColor
            )
        } else {
            Text("No Data")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Sparkline Graph (progressive line with Catmull-Rom curves)

private struct SparklineView: View {
    let history: [WidgetBGPoint]
    let displayDate: Date

    /// Only the points that are actually visible given the left-fade mask.
    /// The mask is fully transparent for the first 25% and fades in through 65%,
    /// so data older than ~2h is effectively invisible. Use last 2h for Y-axis range.
    private var visibleHistory: [WidgetBGPoint] {
        let cutoff = displayDate.addingTimeInterval(-2 * 3600)
        return history.filter { $0.timestamp >= cutoff }
    }

    /// Compute Y-axis range from visible data only, with 2-point padding.
    private var dataRange: (min: Double, max: Double) {
        guard !visibleHistory.isEmpty else { return (40, 300) }
        let values = visibleHistory.map { Double($0.value) }
        let lo = values.min()!
        let hi = values.max()!
        return (lo - 2, hi + 2)
    }

    /// Generate up to 4 "nice" ticks within the visible range.
    private var yTicks: [Int] {
        let range = dataRange
        let lo = Int(ceil(range.min))
        let hi = Int(floor(range.max))
        let span = hi - lo
        guard span > 0 else { return [] }

        let step: Int
        if span <= 20 { step = 5 }
        else if span <= 50 { step = 10 }
        else if span <= 100 { step = 20 }
        else { step = 40 }

        let start = lo + (step - (lo % step)) % step
        var ticks: [Int] = []
        var v = start
        while v <= hi && ticks.count < 4 {
            ticks.append(v)
            v += step
        }
        return ticks
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let topInset: CGFloat = 6 // room for top y-axis label
            let bottomInset: CGFloat = 4 // room for bottom y-axis label
            let chartH = h - topInset - bottomInset
            // Keep sparkline clear of y-axis labels. Labels sit at
            // x = w - 16 in a 28pt trailing-aligned frame, so a
            // 3-digit label like "140" (~17pt wide at 10pt medium)
            // extends left to ~w - 19. A 22pt inset gives ~3pt
            // clearance without a visible dead zone.
            let rightInset: CGFloat = 22
            let sparkW = w - rightInset
            let sorted = history.sorted { $0.timestamp < $1.timestamp }
            // End the x-axis at the most recent reading (not displayDate)
            // so the sparkline's rightmost point always lands at sparkW.
            // Otherwise staleness (~5–10m typical) adds a visible gap on
            // the right — ~4% of sparkW per 7 minutes of staleness.
            let endTime = sorted.last?.timestamp ?? displayDate
            let threeHoursAgo = endTime.addingTimeInterval(-3 * 3600)
            let yMin = dataRange.min
            let yMax = dataRange.max

            // Convert BG points to screen coordinates (within sparkline area)
            let screenPoints: [CGPoint] = sorted.map { point in
                CGPoint(
                    x: xPosition(for: point.timestamp, start: threeHoursAgo, end: endTime, width: sparkW),
                    y: topInset + yPosition(for: Double(point.value), yMin: yMin, yMax: yMax, height: chartH)
                )
            }

            ZStack {
                // Dotted horizontal reference lines + Y-axis labels
                ForEach(yTicks, id: \.self) { value in
                    let y = topInset + yPosition(for: Double(value), yMin: yMin, yMax: yMax, height: chartH)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 0.3, dash: [1, 3]))
                    .foregroundColor(.secondary.opacity(0.15))

                    Text("\(value)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28, alignment: .trailing)
                        .position(x: w - 16, y: y)
                }

                if screenPoints.count >= 2 {
                    Group {
                        // Per-segment fill + stroke — each colored by midpoint BG value
                        ForEach(0 ..< (screenPoints.count - 1), id: \.self) { i in
                            let t = Double(i) / Double(max(screenPoints.count - 2, 1))
                            let lineWidth = 0.3 + t * 1.7
                            let opacity = min(t * 1.4, 1.0)
                            let midBG = Double(sorted[i].value + sorted[i + 1].value) / 2.0
                            let segColor = bgDynamicColor(midBG)

                            // Fill slice under this segment
                            buildSegmentFill(points: screenPoints, index: i, height: topInset + chartH)
                                .fill(
                                    LinearGradient(
                                        colors: [segColor.opacity(0.60), segColor.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            // Stroke with progressive width + opacity
                            buildSingleSegment(points: screenPoints, index: i)
                                .stroke(
                                    segColor.opacity(opacity),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
                                )
                        }
                    }
                    .widgetAccentable()
                }
            }
        }
    }

    // MARK: - Path builders

    /// Builds a single Catmull-Rom curve segment from points[index] to points[index+1].
    private func buildSingleSegment(points: [CGPoint], index: Int) -> Path {
        Path { path in
            let i = index
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

    /// Builds a single segment's fill slice: Catmull-Rom curve closed down to the bottom edge.
    private func buildSegmentFill(points: [CGPoint], index: Int, height: Double) -> Path {
        Path { path in
            let i = index
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
            path.addLine(to: CGPoint(x: p2.x, y: height))
            path.addLine(to: CGPoint(x: p1.x, y: height))
            path.closeSubpath()
        }
    }

    /// Builds the filled area: Catmull-Rom curve closed down to the bottom edge.
    private func buildFillPath(points: [CGPoint], height: Double) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: first)

            if points.count == 2 {
                path.addLine(to: last)
            } else {
                for i in 0 ..< (points.count - 1) {
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

                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }

            path.addLine(to: CGPoint(x: last.x, y: height))
            path.addLine(to: CGPoint(x: first.x, y: height))
            path.closeSubpath()
        }
    }

    // MARK: - Coordinate helpers

    private func xPosition(for date: Date, start: Date, end: Date, width: Double) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(start)
        return max(0, min(width, (elapsed / total) * width))
    }

    private func yPosition(for value: Double, yMin: Double, yMax: Double, height: Double) -> Double {
        guard yMax > yMin else { return height / 2 }
        let clamped = min(max(value, yMin), yMax)
        let fraction = (clamped - yMin) / (yMax - yMin)
        return height * (1 - fraction)
    }
}

// MARK: - Stats Panel (overlays left side of graph)

private struct StatsPanel: View {
    let data: WidgetData
    let displayDate: Date

    private var isStale: Bool {
        displayDate.timeIntervalSince(data.bgTimestamp) >= 16 * 60
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            // Big BG value
            Text(bgText)
                .font(.system(size: 54, weight: .regular))
                .foregroundColor(isStale ? .secondary : bgDynamicColor(Double(data.bgValue)))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
                .overlay {
                    if isStale {
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(.secondary)
                    }
                }

            // Trend arrow + delta + staleness — vertically centered on BG number
            VStack(alignment: .leading, spacing: -3) {
                Text(data.direction)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isStale ? .secondary : .primary)

                if let d = data.delta {
                    Text(deltaText(d))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isStale ? .secondary : .primary)
                        .offset(y: -1.5)
                }

                Text(stalenessText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isStale ? .secondary : .primary)
            }
            .fixedSize()
        }
    }

    private var bgText: String {
        if data.units == "mmol/L" {
            return String(format: "%.1f", Double(data.bgValue) * 0.0555)
        }
        return "\(data.bgValue)"
    }

    private func deltaText(_ delta: Int) -> String {
        if data.units == "mmol/L" {
            let mmol = Double(delta) * 0.0555
            return String(format: "%+.1f", mmol)
        }
        return String(format: "%+d", delta)
    }

    private var stalenessText: String {
        let minutes = Int(displayDate.timeIntervalSince(data.bgTimestamp) / 60)
        if minutes < 1 { return "now" }
        return "\(minutes)m"
    }

    private var stalenessColor: Color {
        return .primary
    }
}
