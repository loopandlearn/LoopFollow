// LoopFollow
// MoreMenuView.swift

import SwiftUI

struct MoreMenuView: View {
    @State private var latestVersion: String?
    @State private var versionTint: Color = .secondary
    @State private var showShareSheet = false
    @State private var shareFiles: [URL] = []
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showSettingsView = false
    @State private var showAlarmsView = false
    @State private var showRemoteView = false
    @State private var showNightscoutView = false
    @State private var showSnoozerView = false
    @State private var showTreatmentsView = false
    @State private var showStatsView = false
    @State private var showHomeView = false
    @State private var showLogView = false

    var body: some View {
        List {
            // Settings
            Section {
                Button { showSettingsView = true } label: {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundStyle(.primary)
                }
            }

            // Features
            Section("Features") {
                ForEach(TabItem.featureOrder) { item in
                    Button { openItem(item) } label: {
                        Label(item.displayName, systemImage: item.icon)
                            .foregroundStyle(.primary)
                    }
                }
            }

            // Logging
            Section("Logging") {
                Button { showLogView = true } label: {
                    Label("View Log", systemImage: "doc.text.magnifyingglass")
                        .foregroundStyle(.primary)
                }

                Button { shareLogs() } label: {
                    Label("Share Logs", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.primary)
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
                buildInfoRow(title: "Version", value: AppVersionManager().version(), color: versionTint)
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
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareFiles)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .navigationDestination(isPresented: $showSettingsView) {
            SettingsMenuView()
        }
        .navigationDestination(isPresented: $showAlarmsView) {
            AlarmsContainerView()
        }
        .navigationDestination(isPresented: $showRemoteView) {
            RemoteContentView()
        }
        .navigationDestination(isPresented: $showNightscoutView) {
            NightscoutContentView()
        }
        .navigationDestination(isPresented: $showSnoozerView) {
            SnoozerView()
        }
        .navigationDestination(isPresented: $showTreatmentsView) {
            TreatmentsView()
        }
        .navigationDestination(isPresented: $showStatsView) {
            AggregatedStatsContentView(mainViewController: MainViewController.shared)
        }
        .navigationDestination(isPresented: $showHomeView) {
            HomeContentView(isModal: true)
        }
        .navigationDestination(isPresented: $showLogView) {
            LogView()
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

    private func openItem(_ item: TabItem) {
        // Check if the item is in the tab bar — if so, switch to it
        let orderedItems = Storage.shared.orderedTabBarItems()
        if let index = orderedItems.firstIndex(of: item) {
            Observable.shared.selectedTabIndex.value = index
            return
        }

        // Otherwise push it onto the navigation stack
        switch item {
        case .home: showHomeView = true
        case .alarms: showAlarmsView = true
        case .remote: showRemoteView = true
        case .nightscout: showNightscoutView = true
        case .snoozer: showSnoozerView = true
        case .treatments: showTreatmentsView = true
        case .stats: showStatsView = true
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
        shareFiles = files
        showShareSheet = true
    }

    private func fetchVersionInfo() async {
        let mgr = AppVersionManager()
        let (latest, newer, blacklisted) = await mgr.checkForNewVersionAsync()
        latestVersion = latest ?? "Unknown"

        let current = mgr.version()
        versionTint = blacklisted ? .red
            : newer ? .orange
            : latest == current ? .green
            : .secondary
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
