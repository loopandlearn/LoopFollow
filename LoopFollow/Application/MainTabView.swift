// LoopFollow
// MainTabView.swift

import Combine
import SwiftUI

struct MainTabView: View {
    @ObservedObject private var selectedTab = Observable.shared.selectedTabIndex
    @ObservedObject private var homePosition = Storage.shared.homePosition
    @ObservedObject private var alarmsPosition = Storage.shared.alarmsPosition
    @ObservedObject private var remotePosition = Storage.shared.remotePosition
    @ObservedObject private var nightscoutPosition = Storage.shared.nightscoutPosition
    @ObservedObject private var snoozerPosition = Storage.shared.snoozerPosition
    @ObservedObject private var statisticsPosition = Storage.shared.statisticsPosition
    @ObservedObject private var treatmentsPosition = Storage.shared.treatmentsPosition

    private var orderedItems: [TabItem] {
        Storage.shared.orderedTabBarItems()
    }

    var body: some View {
        TabView(selection: $selectedTab.value) {
            ForEach(Array(orderedItems.prefix(4).enumerated()), id: \.element) { index, item in
                tabContent(for: item)
                    .tabItem {
                        Label(item.displayName, systemImage: item.icon)
                    }
                    .tag(index)
            }

            NavigationStack {
                MoreMenuView()
            }
            .tabItem {
                Label("Menu", systemImage: "line.3.horizontal")
            }
            .tag(4)
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    @ViewBuilder
    private func tabContent(for item: TabItem) -> some View {
        switch item {
        case .home:
            HomeContentView()
        case .alarms:
            AlarmsContainerView()
        case .remote:
            RemoteContentView()
        case .nightscout:
            NightscoutContentView()
        case .snoozer:
            SnoozerView()
        case .treatments:
            TreatmentsView()
        case .stats:
            NavigationStack {
                AggregatedStatsContentView(mainViewController: nil)
            }
        }
    }
}
