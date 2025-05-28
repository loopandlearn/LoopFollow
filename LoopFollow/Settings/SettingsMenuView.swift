// LoopFollow
// SettingsMenuView.swift
// Created by Jonas Björkert on 2025-05-26.

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    // MARK: – Call-backs

    let onNightscoutVisibilityChange: (_ enabled: Bool) -> Void

    // MARK: – Local state

    @State private var path = NavigationPath()
    @State private var latestVersion: String?
    @State private var versionTint: Color = .secondary
    @State private var navPath = NavigationPath()

    // MARK: – Body

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // ───────── Data settings ─────────
                dataSection

                // ───────── App settings ─────────
                Section("App Settings") {
                    NavigationRow(title: "Background Refresh Settings",
                                  icon: "arrow.clockwise")
                    {
                        path.append(Sheet.backgroundRefresh)
                    }

                    NavigationRow(title: "General Settings",
                                  icon: "gearshape")
                    {
                        path.append(Sheet.general)
                    }

                    NavigationRow(title: "Graph Settings",
                                  icon: "chart.xyaxis.line")
                    {
                        path.append(Sheet.graph)
                    }

                    if IsNightscoutEnabled() {
                        NavigationRow(title: "Information Display Settings",
                                      icon: "info.circle")
                        {
                            path.append(Sheet.infoDisplay)
                        }

                        NavigationRow(title: "Remote Settings",
                                      icon: "antenna.radiowaves.left.and.right")
                        {
                            path.append(Sheet.remote)
                        }
                    }
                }

                // ───────── Alarms ─────────
                Section {
                    NavigationRow(title: "Alarms",
                                  icon: "bell")
                    {
                        path.append(Sheet.alarmsList)
                    }

                    NavigationRow(title: "Alarm Settings",
                                  icon: "bell.badge")
                    {
                        path.append(Sheet.alarmSettings)
                    }
                }

                // ───────── Integrations ─────────
                Section("Integrations") {
                    NavigationRow(title: "Calendar",
                                  icon: "calendar")
                    {
                        path.append(Sheet.calendar)
                    }

                    NavigationRow(title: "Contact",
                                  icon: "person.circle")
                    {
                        path.append(Sheet.contact)
                    }
                }

                // ───────── Advanced / Logs ─────────
                Section("Advanced Settings") {
                    NavigationRow(title: "Advanced Settings",
                                  icon: "exclamationmark.shield")
                    {
                        path.append(Sheet.advanced)
                    }
                }

                Section("Logging") {
                    NavigationRow(title: "View Log",
                                  icon: "doc.text.magnifyingglass")
                    {
                        path.append(Sheet.viewLog)
                    }

                    ActionRow(title: "Share Logs",
                              icon: "square.and.arrow.up",
                              action: shareLogs)
                }

                // ───────── Community ─────────
                Section("Community") {
                    LinkRow(title: "LoopFollow Facebook Group",
                            icon: "person.2.fill",
                            url: URL(string: "https://www.facebook.com/groups/loopfollowlnl")!)
                }

                // ───────── Build info ─────────
                buildInfoSection
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Sheet.self) { $0.destination }
        }
        .task { await refreshVersionInfo() }
    }

    // MARK: – Section builders

    @ViewBuilder
    private var dataSection: some View {
        Section("Data Settings") {
            Picker("Units",
                   selection: Binding(
                       get: { UserDefaultsRepository.units.value },
                       set: { UserDefaultsRepository.units.value = $0 }
                   )) {
                Text("mg/dL").tag("mg/dL")
                Text("mmol/L").tag("mmol/L")
            }
            .pickerStyle(.segmented)

            NavigationRow(title: "Nightscout Settings",
                          icon: "network")
            {
                path.append(Sheet.nightscout)
            }

            NavigationRow(title: "Dexcom Settings",
                          icon: "sensor.tag.radiowaves.forward")
            {
                path.append(Sheet.dexcom)
            }
        }
        .onAppear {
            onNightscoutVisibilityChange(IsNightscoutEnabled())
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
}

// MARK: – Sheet routing

private enum Sheet: Hashable, Identifiable {
    case nightscout, dexcom
    case backgroundRefresh
    case general, graph
    case infoDisplay
    case alarmsList, alarmSettings
    case remote
    case calendar, contact
    case advanced
    case viewLog

    var id: Self { self }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .nightscout: NightscoutSettingsView(viewModel: .init())
        case .dexcom: DexcomSettingsView(viewModel: .init())
        case .backgroundRefresh: BackgroundRefreshSettingsView(viewModel: .init())
        case .general: GeneralSettingsView()
        case .graph: GraphSettingsView()
        case .infoDisplay: InfoDisplaySettingsView(viewModel: .init())
        case .alarmsList: AlarmListView()
        case .alarmSettings: AlarmSettingsView()
        case .remote: RemoteSettingsView(viewModel: .init())
        case .calendar: CalendarSettingsView()
        case .contact: ContactSettingsView(viewModel: .init())
        case .advanced: AdvancedSettingsView(viewModel: .init())
        case .viewLog: LogView(viewModel: .init())
        }
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
