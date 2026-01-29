// LoopFollow
// SettingsMenuView.swift

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    // MARK: - Observed Objects

    @ObservedObject private var nightscoutURL = Storage.shared.url
    @ObservedObject private var settingsPath = Observable.shared.settingsPath

    // MARK: – Local state

    @State private var latestVersion: String?
    @State private var versionTint: Color = .secondary
    @State private var showingTabCustomization = false

    // MARK: – Observed objects

    @ObservedObject private var url = Storage.shared.url

    // MARK: – Body

    var body: some View {
        NavigationStack(path: $settingsPath.value) {
            List {
                // ───────── Data settings ─────────
                dataSection

                // ───────── App settings ─────────
                Section("App Settings") {
                    NavigationRow(title: "Background Refresh Settings",
                                  icon: "arrow.clockwise")
                    {
                        settingsPath.value.append(Sheet.backgroundRefresh)
                    }

                    NavigationRow(title: "General Settings",
                                  icon: "gearshape")
                    {
                        settingsPath.value.append(Sheet.general)
                    }

                    NavigationRow(title: "Graph Settings",
                                  icon: "chart.xyaxis.line")
                    {
                        settingsPath.value.append(Sheet.graph)
                    }

                    NavigationRow(title: "Tab Settings",
                                  icon: "rectangle.3.group")
                    {
                        showingTabCustomization = true
                    }

                    NavigationRow(title: "Import/Export Settings",
                                  icon: "square.and.arrow.down")
                    {
                        settingsPath.value.append(Sheet.importExport)
                    }

                    if !nightscoutURL.value.isEmpty {
                        NavigationRow(title: "Information Display Settings",
                                      icon: "info.circle")
                        {
                            settingsPath.value.append(Sheet.infoDisplay)
                        }

                        NavigationRow(title: "Remote Settings",
                                      icon: "antenna.radiowaves.left.and.right")
                        {
                            settingsPath.value.append(Sheet.remote)
                        }
                    }
                }

                // ───────── Alarms ─────────
                Section("Alarms") {
                    NavigationRow(title: "Alarm Settings",
                                  icon: "bell.badge")
                    {
                        settingsPath.value.append(Sheet.alarmSettings)
                    }
                }

                // ───────── Integrations ─────────
                Section("Integrations") {
                    NavigationRow(title: "Calendar",
                                  icon: "calendar")
                    {
                        settingsPath.value.append(Sheet.calendar)
                    }

                    NavigationRow(title: "Contact",
                                  icon: "person.circle")
                    {
                        settingsPath.value.append(Sheet.contact)
                    }
                }

                // ───────── Advanced / Logs ─────────
                Section("Advanced Settings") {
                    NavigationRow(title: "Advanced Settings",
                                  icon: "exclamationmark.shield")
                    {
                        settingsPath.value.append(Sheet.advanced)
                    }
                }

                Section("Logging") {
                    NavigationRow(title: "View Log",
                                  icon: "doc.text.magnifyingglass")
                    {
                        settingsPath.value.append(Sheet.viewLog)
                    }

                    ActionRow(title: "Share Logs",
                              icon: "square.and.arrow.up",
                              action: shareLogs)
                }

                // ───────── Build info ─────────
                buildInfoSection
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Sheet.self) { $0.destination }
            .sheet(isPresented: $showingTabCustomization) {
                TabCustomizationModal(
                    isPresented: $showingTabCustomization,
                    onApply: {
                        // No-op - changes are applied silently via observers
                    }
                )
            }
        }
        .task { await refreshVersionInfo() }
    }

    // MARK: – Section builders

    private var dataSection: some View {
        Section("Data Settings") {
            Picker("Units",
                   selection: Binding(
                       get: { Storage.shared.units.value },
                       set: { Storage.shared.units.value = $0 }
                   )) {
                Text("mg/dL").tag("mg/dL")
                Text("mmol/L").tag("mmol/L")
            }
            .pickerStyle(.segmented)

            NavigationRow(title: "Nightscout Settings",
                          icon: "network")
            {
                settingsPath.value.append(Sheet.nightscout)
            }

            NavigationRow(title: "Dexcom Settings",
                          icon: "sensor.tag.radiowaves.forward")
            {
                settingsPath.value.append(Sheet.dexcom)
            }
        }
    }

    @ViewBuilder
    private var buildInfoSection: some View {
        let build = BuildDetails.default
        let ver = AppVersionManager().version()

        Section("Build Information") {
            keyValue("Version", ver, tint: versionTint)
            keyValue("Latest version", latestVersion ?? "Fetching…")

            if !(build.isMacApp() || build.isSimulatorBuild()) {
                keyValue(build.expirationHeaderString,
                         dateTimeUtils.formattedDate(from: build.calculateExpirationDate()))
            }
            keyValue("Built",
                     dateTimeUtils.formattedDate(from: build.buildDate()))
            keyValue("Branch", build.branchAndSha)
        }
    }

    // MARK: – Helpers

    private func keyValue(_ key: String,
                          _ value: String,
                          tint: Color = .secondary) -> some View
    {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(tint)
        }
    }

    private func refreshVersionInfo() async {
        let mgr = AppVersionManager()
        let (latest, newer, blacklisted) = await mgr.checkForNewVersionAsync()
        latestVersion = latest ?? "Unknown"

        let current = mgr.version()
        versionTint = blacklisted ? .red
            : newer ? .orange
            : latest == current ? .green
            : .secondary
    }

    private func shareLogs() {
        let files = LogManager.shared.logFilesForTodayAndYesterday()
        guard !files.isEmpty else {
            UIApplication.shared.topMost?.presentSimpleAlert(
                title: "No Logs Available",
                message: "There are no logs to share."
            )
            return
        }
        let avc = UIActivityViewController(activityItems: files,
                                           applicationActivities: nil)
        UIApplication.shared.topMost?.present(avc, animated: true)
    }

    private func handleTabReorganization() {
        // Rebuild the tab bar with the new configuration
        MainViewController.rebuildTabsIfNeeded()
    }
}

// MARK: – Sheet routing

private enum Sheet: Hashable, Identifiable {
    case nightscout, dexcom
    case backgroundRefresh
    case general, graph
    case infoDisplay
    case alarmSettings
    case remote
    case importExport
    case calendar, contact
    case advanced
    case viewLog
    case aggregatedStats

    var id: Self {
        self
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .nightscout: NightscoutSettingsView(viewModel: .init())
        case .dexcom: DexcomSettingsView(viewModel: .init())
        case .backgroundRefresh: BackgroundRefreshSettingsView(viewModel: .init())
        case .general: GeneralSettingsView()
        case .graph: GraphSettingsView()
        case .infoDisplay: InfoDisplaySettingsView(viewModel: .init())
        case .alarmSettings: AlarmSettingsView()
        case .remote: RemoteSettingsView(viewModel: .init())
        case .importExport: ImportExportSettingsView()
        case .calendar: CalendarSettingsView()
        case .contact: ContactSettingsView(viewModel: .init())
        case .advanced: AdvancedSettingsView(viewModel: .init())
        case .viewLog: LogView(viewModel: .init())
        case .aggregatedStats:
            AggregatedStatsViewWrapper()
        }
    }
}

/// Helper view to access MainViewController
struct AggregatedStatsViewWrapper: View {
    @State private var mainViewController: MainViewController?

    var body: some View {
        Group {
            if let mainVC = mainViewController {
                AggregatedStatsView(viewModel: AggregatedStatsViewModel(mainViewController: mainVC))
            } else {
                Text("Loading stats...")
                    .onAppear {
                        mainViewController = getMainViewController()
                    }
            }
        }
    }

    private func getMainViewController() -> MainViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController
        else {
            return nil
        }

        if let mainVC = rootVC as? MainViewController {
            return mainVC
        }

        if let navVC = rootVC as? UINavigationController,
           let mainVC = navVC.viewControllers.first as? MainViewController
        {
            return mainVC
        }

        if let tabVC = rootVC as? UITabBarController {
            for vc in tabVC.viewControllers ?? [] {
                if let mainVC = vc as? MainViewController {
                    return mainVC
                }
                if let navVC = vc as? UINavigationController,
                   let mainVC = navVC.viewControllers.first as? MainViewController
                {
                    return mainVC
                }
            }
        }

        return nil
    }
}

// MARK: – UIKit helpers (unchanged)

import UIKit

extension UIApplication {
    var topMost: UIViewController? {
        guard var top = keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

extension UIViewController {
    func presentSimpleAlert(title: String, message: String) {
        let a = UIAlertController(title: title,
                                  message: message,
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
