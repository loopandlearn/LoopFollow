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
    @State private var searchText = ""
    @ObservedObject private var nightscoutURL = Storage.shared.url

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            if isSearching {
                searchResultsSection
            } else {
                menuContent
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search")
        .overlay {
            if isSearching, filteredSearchItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Results")
                        .font(.headline)
                    Text("No matches for “\(searchText)”.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
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

    // MARK: - Menu content

    @ViewBuilder
    private var menuContent: some View {
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
                    selectFeature(item)
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
            ForEach(MoreMenuView.supportLinks, id: \.url) { link in
                Link(destination: link.url) {
                    HStack {
                        Label(link.title, systemImage: link.icon)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
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

    private func selectFeature(_ item: TabItem) {
        let tabs = Storage.shared.orderedTabBarItems()
        if let tabIndex = tabs.firstIndex(of: item) {
            Observable.shared.selectedTabIndex.value = tabIndex
        } else {
            pendingRoute = MenuRoute(item)
        }
    }

    // MARK: - Search

    /// External Support & Community links, shared by the menu and search so their
    /// titles live in one place.
    private static let supportLinks: [(title: String, icon: String, url: URL)] = [
        ("LoopFollow Docs", "book", URL(string: "https://loopfollowdocs.org/")!),
        ("Loop and Learn Discord", "bubble.left.and.bubble.right", URL(string: "https://discord.gg/KQgk3gzuYU")!),
        ("LoopFollow Facebook Group", "person.2.fill", URL(string: "https://www.facebook.com/groups/loopfollowlnl")!),
    ]

    /// The searchable universe, assembled from the same sources that render the
    /// menu — the Settings routes, the tab features, and the static rows — so it
    /// never needs to be kept in sync by hand.
    private var searchItems: [MenuSearchItem] {
        var items: [MenuSearchItem] = [
            MenuSearchItem(title: "Settings", icon: "gearshape", keywords: [], kind: .settings(.settings)),
        ]

        for (_, routes) in SettingsRoute.menuSections(nightscoutConfigured: !nightscoutURL.value.isEmpty) {
            for route in routes {
                items.append(MenuSearchItem(title: route.title, icon: route.icon, keywords: route.keywords, kind: .settings(route)))
            }
        }

        for item in TabItem.featureOrder {
            items.append(MenuSearchItem(title: item.displayName, icon: item.icon, keywords: [], kind: .feature(item)))
        }

        items.append(MenuSearchItem(title: "View Log", icon: "doc.text.magnifyingglass", keywords: ["logging"], kind: .viewLog))
        items.append(MenuSearchItem(title: "Share Logs", icon: "square.and.arrow.up", keywords: ["logging"], kind: .shareLogs))

        for link in MoreMenuView.supportLinks {
            items.append(MenuSearchItem(title: link.title, icon: link.icon, keywords: ["support", "community"], kind: .link(link.url)))
        }

        return items
    }

    private var filteredSearchItems: [MenuSearchItem] {
        searchItems.filter(matches)
    }

    private func matches(_ item: MenuSearchItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(query)
            || item.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            ForEach(filteredSearchItems) { item in
                searchRow(for: item)
            }
        }
    }

    @ViewBuilder
    private func searchRow(for item: MenuSearchItem) -> some View {
        switch item.kind {
        case let .settings(route):
            NavigationRow(title: item.title, icon: item.icon, value: route)
        case let .feature(feature):
            FullRowButton(showsChevron: true) { selectFeature(feature) } label: {
                Label(item.title, systemImage: item.icon)
            }
        case .viewLog:
            FullRowButton(showsChevron: true) { pendingRoute = .log } label: {
                Label(item.title, systemImage: item.icon)
            }
        case .shareLogs:
            FullRowButton { shareLogs() } label: {
                Label(item.title, systemImage: item.icon)
            }
        case let .link(url):
            Link(destination: url) {
                HStack {
                    Label(item.title, systemImage: item.icon)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.tertiary)
                }
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

        let noticeView = ShareLogNoticeView(
            onCancel: {
                UIApplication.shared.topMost?.dismiss(animated: true)
            },
            onShare: { noticeText in
                let presenter = UIApplication.shared.topMost
                presenter?.dismiss(animated: true) {
                    presentLogShareSheet(noticeText: noticeText, logFiles: files)
                }
            }
        )
        let host = UIHostingController(rootView: noticeView)
        host.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        host.modalPresentationStyle = .formSheet
        UIApplication.shared.topMost?.present(host, animated: true)
    }

    private func presentLogShareSheet(noticeText: String, logFiles: [URL]) {
        var items: [Any] = logFiles
        if let noticeURL = writeShareNoticeFile(text: noticeText) {
            items.insert(noticeURL, at: 0)
        }
        let avc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        UIApplication.shared.topMost?.present(avc, animated: true)
    }

    private func writeShareNoticeFile(text: String) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = formatter.string(from: Date())

        let version = AppVersionManager().version()
        let branchAndSha = BuildDetails.default.branchAndSha

        let body = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "(no description provided)"
            : text

        let contents = """
        LoopFollow Log Share Notice
        Date: \(ISO8601DateFormatter().string(from: Date()))
        App version: \(version) (\(branchAndSha))

        User description:
        \(body)
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareNotice_\(timestamp).txt")
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            LogManager.shared.log(category: .general, message: "Failed to write share notice file: \(error)")
            return nil
        }
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

// MARK: – Search model

/// A single searchable menu entry. Assembled from the menu's existing data
/// sources (see `MoreMenuView.searchItems`); `kind` carries how tapping it
/// should behave so results reuse the same navigation as the live rows.
private struct MenuSearchItem: Identifiable {
    let title: String
    let icon: String
    let keywords: [String]
    let kind: Kind

    enum Kind {
        case settings(SettingsRoute)
        case feature(TabItem)
        case viewLog
        case shareLogs
        case link(URL)
    }

    var id: String {
        switch kind {
        case let .settings(route): return "settings.\(route)"
        case let .feature(item): return "feature.\(item.rawValue)"
        case .viewLog: return "viewLog"
        case .shareLogs: return "shareLogs"
        case let .link(url): return "link.\(url.absoluteString)"
        }
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
