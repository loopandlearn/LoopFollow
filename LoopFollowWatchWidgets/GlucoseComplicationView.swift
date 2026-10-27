// LoopFollow
// GlucoseComplicationView.swift

import Charts
import SwiftUI
import WidgetKit

struct GlucoseComplicationView: View {
    let entry: GlucoseEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: GlucoseSnapshot? { entry.state?.snapshot }

    private var isStale: Bool {
        guard let snapshot else { return true }
        return entry.date.timeIntervalSince(snapshot.updatedAt) >= WatchFormat.staleAfter
    }

    private var bgText: String {
        guard let snapshot else { return "--" }
        return WatchFormat.glucose(snapshot.glucose, unit: snapshot.unit)
    }

    private var bgColor: Color {
        guard let state = entry.state, let snapshot else { return .secondary }
        if isStale { return .secondary }
        return WatchFormat.bgColor(snapshot.glucose, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl, colored: state.colorBGText)
    }

    private var trendText: String {
        snapshot.map { WatchFormat.trendArrow($0.trend) } ?? ""
    }

    private var deltaText: String {
        snapshot.map { WatchFormat.delta($0.delta, unit: $0.unit) } ?? ""
    }

    private var ageText: String {
        snapshot.map { WatchFormat.minutesAgo($0.updatedAt, now: entry.date) } ?? ""
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryCorner:
            corner
        default:
            inline
        }
    }

    private var circular: some View {
        VStack(spacing: -2) {
            Text(bgText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(bgColor)
                .strikethrough(isStale, color: .red)
                .minimumScaleFactor(0.5)
            Text(trendText)
                .font(.system(size: 12, weight: .bold))
            Text(ageText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(bgText)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(bgColor)
                        .strikethrough(isStale, color: .red)
                    Text(trendText)
                        .font(.system(size: 14, weight: .bold))
                }
                Text("\(deltaText)  \(ageText)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetAccentable()
            sparkline
        }
    }

    /// Last two hours of readings in range colors.
    @ViewBuilder
    private var sparkline: some View {
        if let state = entry.state {
            let start = entry.date.addingTimeInterval(-2 * 3600)
            let readings = state.readings.filter { $0.date >= start }
            Chart {
                RuleMark(y: .value("High", state.highMgdl))
                    .foregroundStyle(Color.yellow.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                RuleMark(y: .value("Low", state.lowMgdl))
                    .foregroundStyle(Color.red.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                ForEach(readings, id: \.t) { reading in
                    PointMark(x: .value("Time", reading.date), y: .value("BG", min(max(reading.v, 40), 300)))
                        .symbolSize(6)
                        .foregroundStyle(WatchFormat.bgColor(reading.v, lowMgdl: state.lowMgdl, highMgdl: state.highMgdl))
                }
            }
            .chartXScale(domain: start ... entry.date)
            .chartYScale(domain: 40 ... 300)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
    }

    private var corner: some View {
        Text(bgText)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(bgColor)
            .widgetCurvesContent()
            .widgetLabel {
                Text("\(trendText) \(deltaText) \(ageText)")
            }
    }

    private var inline: some View {
        Text(snapshot == nil ? "LoopFollow --" : "\(bgText) \(trendText) \(deltaText) · \(ageText)")
    }
}
