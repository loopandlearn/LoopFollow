// LoopFollow
// MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @ObservedObject private var selectedTab = Observable.shared.selectedTabIndex
    @ObservedObject private var appearanceMode = Storage.shared.appearanceMode
    @ObservedObject private var homePosition = Storage.shared.homePosition
    @ObservedObject private var alarmsPosition = Storage.shared.alarmsPosition
    @ObservedObject private var remotePosition = Storage.shared.remotePosition
    @ObservedObject private var nightscoutPosition = Storage.shared.nightscoutPosition
    @ObservedObject private var snoozerPosition = Storage.shared.snoozerPosition
    @ObservedObject private var statisticsPosition = Storage.shared.statisticsPosition
    @ObservedObject private var treatmentsPosition = Storage.shared.treatmentsPosition

    @State private var showTelemetryConsent = false

    private var orderedItems: [TabItem] {
        Storage.shared.orderedTabBarItems()
    }

    var body: some View {
        TabView(selection: $selectedTab.value) {
            ForEach(Array(orderedItems.prefix(4).enumerated()), id: \.element) { index, item in
                tabContent(for: item)
                    .tabItem {
                        tabLabel(item.displayName, systemImage: item.icon)
                    }
                    .tag(index)
            }

            NavigationStack {
                MoreMenuView()
            }
            .tabItem {
                tabLabel("Menu", systemImage: "line.3.horizontal")
            }
            .tag(4)
        }
        .preferredColorScheme(appearanceMode.value.colorScheme)
        .onAppear {
            // Start the data pipeline as soon as the UI appears, independent of
            // tab layout. Without this, a user who moves Home into the Menu would
            // have no MainViewController — and therefore no data fetching, alarms,
            // or background audio — until they manually opened Home. Tying it to
            // onAppear (not app launch) keeps it off the BG-only refresh path.
            MainViewController.bootstrap()

            // One-time consent prompt. Previously presented by SceneDelegate,
            // which was removed in the storyboard→SwiftUI migration; without
            // this, fresh installs stay permanently undecided and telemetry
            // never sends. The storage flag keeps it to a single appearance.
            if !Storage.shared.telemetryConsentDecisionMade.value {
                showTelemetryConsent = true
            }
        }
        .sheet(isPresented: $showTelemetryConsent) {
            // User must explicitly choose — no swipe-to-dismiss.
            TelemetryConsentView()
                .interactiveDismissDisabled(true)
        }
    }

    /// Tab bar label with a fixed-size icon so large Dynamic Type sizes don't
    /// grow the symbol and squeeze the title. The title font is pinned in AppDelegate.
    private func tabLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
            if let image = UIImage(systemName: systemImage, withConfiguration: config) {
                Image(uiImage: image.withRenderingMode(.alwaysTemplate))
            } else {
                Image(systemName: systemImage)
            }
        }
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
                AggregatedStatsContentView(mainViewController: MainViewController.shared)
            }
        }
    }
}
