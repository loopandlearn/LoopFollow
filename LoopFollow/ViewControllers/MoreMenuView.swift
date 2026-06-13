// LoopFollow
// MoreMenuView.swift

import SwiftUI
import UIKit

struct MoreMenuView: View {
    @State private var pendingRoute: MenuRoute?
    @State private var latestVersion: String?
    @State private var versionTint: Color = .secondary
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var currentVersion: String = AppVersionManager().version()

    var body: some View {
        List {
            // Settings
            Section {
                NavigationLink(value: SettingsRoute.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            // Features
            Section("Features") {
                ForEach(TabItem.featureOrder) { item in
                    FullRowButton(showsChevron: true) {
                        let tabs = Storage.shared.orderedTabBarItems()
                        if let tabIndex = tabs.firstIndex(of: item) {
                            Observable.shared.selectedTabIndex.value = tabIndex
                        } else {
                            pendingRoute = MenuRoute(item)
                        }
                    } label: {
                        Label(item.displayName, systemImage: item.icon)
                    }
                }
            }

            // Logging
            Section("Logging") {
                FullRowButton(showsChevron: true) { pendingRoute = .log } label: {
                    Label("View Log", systemImage: "doc.text.magnifyingglass")
                }

                FullRowButton { shareLogs() } label: {
                    Label("Share Logs", systemImage: "square.and.arrow.up")
                }
            }

            // Support & Community
            Section("Support & Community") {
                Link(destination: URL(string: "https://loopfollowdocs.org/")!) {
                    HStack {
                        Label("LoopFollow Docs", systemImage: "book")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                }

                Link(destination: URL(string: "https://discord.gg/KQgk3gzuYU")!) {
                    HStack {
                        Label("Loop and Learn Discord", systemImage: "bubble.left.and.bubble.right")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                }

                Link(destination: URL(string: "https://www.facebook.com/groups/loopfollowlnl")!) {
                    HStack {
                        Label("LoopFollow Facebook Group", systemImage: "person.2.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Build Information
            Section("Build Information") {
                buildInfoRow(title: "Version", value: currentVersion, color: versionTint)
                buildInfoRow(title: "Latest version", value: latestVersion ?? "Fetching…", color: .secondary)

                let build = BuildDetails.default
                if !(build.isMacApp() || build.isSimulatorBuild()) {
                    buildInfoRow(
                        title: build.expirationHeaderString,
                        value: dateTimeUtils.formattedDate(from: build.calculateExpirationDate()),
                        color: .secondary
                    )
                }

                buildInfoRow(title: "Built", value: dateTimeUtils.formattedDate(from: build.buildDate()), color: .secondary)
                buildInfoRow(title: "Branch", value: build.branchAndSha, color: .secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await fetchVersionInfo()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .navigationDestination(for: SettingsRoute.self) { $0.destination }
        .navigationDestination(
            isPresented: Binding(
                get: { pendingRoute != nil },
                set: { if !$0 { pendingRoute = nil } }
            )
        ) {
            if let route = pendingRoute {
                route.destination
            }
        }
    }

    // MARK: - Helpers

    private func buildInfoRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(color)
        }
    }

    private func shareLogs() {
        let files = LogManager.shared.logFilesForTodayAndYesterday()
        guard !files.isEmpty else {
            alertTitle = "No Logs Available"
            alertMessage = "There are no logs to share."
            showAlert = true
            return
        }
        let avc = UIActivityViewController(activityItems: files, applicationActivities: nil)
        UIApplication.shared.topMost?.present(avc, animated: true)
    }

    private func fetchVersionInfo() async {
        let mgr = AppVersionManager()
        let (latest, newer, blacklisted) = await mgr.checkForNewVersionAsync()
        latestVersion = latest ?? "Unknown"

        versionTint = blacklisted ? .red
            : newer ? .orange
            : latest == currentVersion ? .green
            : .secondary
    }
}

// MARK: – Full-row tappable button

private struct FullRowButton<Label: View>: View {
    var showsChevron: Bool = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack {
                label()
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Menu routing

enum MenuRoute: Hashable {
    case home
    case alarms
    case remote
    case nightscout
    case snoozer
    case treatments
    case stats
    case log

    init(_ item: TabItem) {
        switch item {
        case .home: self = .home
        case .alarms: self = .alarms
        case .remote: self = .remote
        case .nightscout: self = .nightscout
        case .snoozer: self = .snoozer
        case .treatments: self = .treatments
        case .stats: self = .stats
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home: HomeContentView(isModal: true)
        case .alarms: AlarmsContainerView(embedsInNavigationStack: false)
        case .remote: RemoteContentView()
        case .nightscout: NightscoutContentView()
        case .snoozer: SnoozerView()
        case .treatments: TreatmentsView()
        case .stats: AggregatedStatsContentView(mainViewController: MainViewController.shared)
        case .log: LogView()
        }
    }
}
