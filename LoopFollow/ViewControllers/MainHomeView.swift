// LoopFollow
// MainHomeView.swift

import Charts
import SwiftUI

struct MainHomeView: View {
    let bgChart: LineChartView
    let bgChartFull: LineChartView
    @ObservedObject var infoManager: InfoManager
    @ObservedObject var statsModel: StatsDisplayModel

    @ObservedObject var showSmallGraph = Storage.shared.showSmallGraph
    @ObservedObject var showStats = Storage.shared.showStats
    @ObservedObject var hideInfoTable = Storage.shared.hideInfoTable
    @ObservedObject var smallGraphHeight = Storage.shared.smallGraphHeight
    @ObservedObject var url = Storage.shared.url
    @ObservedObject var graphTimeZoneEnabled = Storage.shared.graphTimeZoneEnabled
    @ObservedObject var graphTimeZoneIdentifier = Storage.shared.graphTimeZoneIdentifier

    var onRefresh: (() -> Void)?
    var onStatsTap: (() -> Void)?

    private var timeZoneOverride: String? {
        guard graphTimeZoneEnabled.value,
              let tz = TimeZone(identifier: graphTimeZoneIdentifier.value)
        else { return nil }
        return tz.identifier
    }

    private var isNightscoutEnabled: Bool {
        !url.value.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            // Top section: BG display + info table
            HStack(spacing: 10) {
                BGDisplayView(onRefresh: onRefresh)

                if isNightscoutEnabled && !hideInfoTable.value {
                    InfoTableView(infoManager: infoManager, timeZoneOverride: timeZoneOverride)
                        .frame(minWidth: 160, maxWidth: 250)
                        .overlay(
                            Rectangle()
                                .fill(Color(UIColor.darkGray))
                                .frame(width: 2),
                            alignment: .leading
                        )
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            // Main chart (fills remaining space)
            LineChartWrapper(chartView: bgChart)

            // Small overview chart
            if showSmallGraph.value {
                LineChartWrapper(chartView: bgChartFull)
                    .frame(height: CGFloat(smallGraphHeight.value))
            }

            // Statistics
            if showStats.value {
                StatsDisplayView(model: statsModel, onTap: onStatsTap)
            }
        }
        .padding(8)
    }
}
