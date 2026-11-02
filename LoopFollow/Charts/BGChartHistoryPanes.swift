// LoopFollow
// BGChartHistoryPanes.swift

import Charts
import SwiftUI

/// One device status history pane (IOB, COB or sensitivity ratio) laid
/// out over the main chart's render window. Like BGChartCanvas, it compares
/// only cheap metadata so panning, which translates it, skips its body.
struct BGChartHistoryPaneCanvas: View, Equatable {
    let pane: BGChartHistory.Pane
    let generation: Int
    let now: Date
    let windowStart: Date
    let windowEnd: Date
    let canvasWidth: CGFloat
    let height: CGFloat

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.generation == rhs.generation &&
            lhs.pane.kind == rhs.pane.kind &&
            lhs.now == rhs.now &&
            lhs.windowStart == rhs.windowStart &&
            lhs.windowEnd == rhs.windowEnd &&
            lhs.canvasWidth == rhs.canvasWidth &&
            lhs.height == rhs.height
    }

    var body: some View {
        let points = chartWindowedLine(pane.points, windowStart: windowStart, windowEnd: windowEnd) { $0.date }
        let color = pane.kind.color
        Chart {
            ForEach(pane.ticks, id: \.self) { tick in
                RuleMark(y: .value("tick", tick))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.gray.opacity(0.4))
            }
            if pane.kind.fillsArea {
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("time", pt.date),
                        yStart: .value("baseline", pane.baseline),
                        yEnd: .value(pane.kind.title, pt.value),
                        series: .value("series", "area-\(pt.segment)")
                    )
                    .foregroundStyle(color.opacity(0.25))
                    .interpolationMethod(.linear)
                }
            }
            if now >= windowStart, now <= windowEnd {
                RuleMark(x: .value("now", now))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.gray.opacity(0.6))
            }
            ForEach(points) { pt in
                LineMark(
                    x: .value("time", pt.date),
                    y: .value(pane.kind.title, pt.value),
                    series: .value("series", "line-\(pt.segment)")
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.linear)
            }
        }
        .chartXScale(domain: windowStart ... windowEnd)
        .chartYScale(domain: pane.yDomain)
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(width: canvasWidth, height: height)
    }
}

/// Pinned title and value labels for a history pane, drawn over its
/// scrolling canvas. Labels are kept inside the pane so they never spill into
/// a neighbouring one.
struct BGChartHistoryPaneAxisOverlay: View, Equatable {
    let pane: BGChartHistory.Pane
    let generation: Int

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.generation == rhs.generation && lhs.pane.kind == rhs.pane.kind
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let span = pane.yDomain.upperBound - pane.yDomain.lowerBound
            ZStack(alignment: .topLeading) {
                ForEach(pane.ticks, id: \.self) { tick in
                    let fraction = span > 0 ? (pane.yDomain.upperBound - tick) / span : 0.5
                    Text(pane.kind.axisLabel(tick))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                        .frame(width: geo.size.width, height: 14, alignment: .trailing)
                        .position(x: geo.size.width / 2, y: min(max(CGFloat(fraction) * height, 7), height - 7))
                }

                Text(pane.kind.title)
                    .font(.caption2.bold())
                    .foregroundStyle(pane.kind.color)
                    .padding(.leading, 4)
                    .padding(.top, 2)

                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 0.5)
            }
        }
    }
}
