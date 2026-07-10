// LoopFollow
// MainHomeView.swift

import SwiftUI

struct MainHomeView: View {
    // Deliberately not @ObservedObject: this view only passes the model on.
    // The chart views observe what they each need, so data and (especially)
    // per-frame pan/zoom updates don't re-evaluate this whole screen.
    let chartModel: BGChartModel
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
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
            BGChartView(model: chartModel, config: .main)

            // Small overview chart
            if showSmallGraph.value {
                BGChartView(model: chartModel, config: .small)
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
