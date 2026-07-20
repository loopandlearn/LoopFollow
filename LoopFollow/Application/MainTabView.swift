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
    @ObservedObject private var activeBanner = Observable.shared.activeBanner

    @State private var showTelemetryConsent = false
    @State private var showOnboarding = false

    private var orderedItems: [TabItem] {
        Storage.shared.orderedTabBarItems()
    }

    var body: some View {
        // The banner sits in a VStack above the TabView (rather than a
        // .safeAreaInset) so the UIKit-hosted Home content is physically
        // pushed down too — safe-area changes don't propagate into
        // UIViewControllerRepresentable.
        VStack(spacing: 0) {
            if let message = activeBanner.value {
                AppBannerView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            tabView
        }
        .animation(.easeInOut(duration: 0.25), value: activeBanner.value)
    }

    private var tabView: some View {
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
        .preferredColorScheme(appearanceMode.value.colorScheme)
        .onAppear {
            // Start the data pipeline as soon as the UI appears, independent of
            // tab layout. Without this, a user who moves Home into the Menu would
            // have no MainViewController — and therefore no data fetching, alarms,
            // or background audio — until they manually opened Home. Tying it to
            // onAppear (not app launch) keeps it off the BG-only refresh path.
            MainViewController.bootstrap()

            // Show the first-run onboarding once for everyone. Returning users
            // get a prominent Skip on the welcome screen. The telemetry consent
            // prompt is deferred until onboarding is dismissed so the two never
            // appear on top of one another.
            if !Storage.shared.hasCompletedOnboarding.value {
                Observable.shared.isOnboardingActive.value = true
                showOnboarding = true
            } else {
                runPostOnboardingPrompts()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            Observable.shared.isOnboardingActive.value = false

            // Covers both finishing and skipping onboarding — the telemetry and
            // notification steps live inside the flow, so anyone who skips still
            // needs these handled here.
            runPostOnboardingPrompts()
        }) {
            OnboardingContainerView(onClose: { showOnboarding = false })
        }
        .sheet(isPresented: $showTelemetryConsent, onDismiss: {
            // Ask for notifications only once telemetry is resolved, so the system
            // prompt never stacks on top of the consent sheet.
            requestNotificationsIfAlarmsEnabled()
        }) {
            // User must explicitly choose — no swipe-to-dismiss.
            TelemetryConsentView()
                .interactiveDismissDisabled(true)
        }
    }

    /// Runs after onboarding closes, whether it was completed or skipped. Telemetry
    /// consent and notification permission both live inside the onboarding flow, so
    /// a skip would otherwise bypass them. Telemetry consent goes first (as a
    /// sheet); the notification request follows on its dismissal so the two never
    /// appear at once. When the user completed the flow these are already decided,
    /// so both calls are no-ops.
    private func runPostOnboardingPrompts() {
        if !Storage.shared.telemetryConsentDecisionMade.value {
            showTelemetryConsent = true // notifications requested on its dismiss
        } else {
            requestNotificationsIfAlarmsEnabled()
        }
    }

    /// Deferred-permission policy: only ask for notifications once there's an
    /// enabled alarm that needs them. Safe to call repeatedly — it's a no-op once
    /// the status is determined.
    private func requestNotificationsIfAlarmsEnabled() {
        if Storage.shared.alarms.value.contains(where: { $0.isEnabled }) {
            NotificationAuthorization.requestIfNeeded()
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
