// LoopFollow
// SettingsMenuView.swift

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    // MARK: - Init parameters

    /// When true, shows a close button for modal dismissal
    var isModal: Bool = false

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Observed Objects

    @ObservedObject private var nightscoutURL = Storage.shared.url
    @ObservedObject private var settingsPath = Observable.shared.settingsPath

    // MARK: – Observed objects

    @ObservedObject private var url = Storage.shared.url

    // MARK: – Body

    var body: some View {
        NavigationStack(path: $settingsPath.value) {
            List {
                // ───────── App settings ─────────
                Section("App Settings") {
                    NavigationRow(title: "General",
                                  icon: "gearshape")
                    {
                        settingsPath.value.append(Sheet.general)
                    }

                    NavigationRow(title: "Background Refresh",
                                  icon: "arrow.clockwise")
                    {
                        settingsPath.value.append(Sheet.backgroundRefresh)
                    }

                    NavigationRow(title: "Graph",
                                  icon: "chart.xyaxis.line")
                    {
                        settingsPath.value.append(Sheet.graph)
                    }

                    NavigationRow(title: "Tabs",
                                  icon: "rectangle.3.group")
                    {
                        settingsPath.value.append(Sheet.tabs)
                    }

                    NavigationRow(title: "Import/Export",
                                  icon: "square.and.arrow.down")
                    {
                        settingsPath.value.append(Sheet.importExport)
                    }

                    if !nightscoutURL.value.isEmpty {
                        NavigationRow(title: "Information Display",
                                      icon: "info.circle")
                        {
                            settingsPath.value.append(Sheet.infoDisplay)
                        }

                        NavigationRow(title: "Remote",
                                      icon: "antenna.radiowaves.left.and.right")
                        {
                            settingsPath.value.append(Sheet.remote)
                        }
                    }

                    NavigationRow(title: "Alarms",
                                  icon: "bell.badge")
                    {
                        settingsPath.value.append(Sheet.alarmSettings)
                    }
                }

                // ───────── Data settings ─────────
                dataSection

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
                Section("Advanced") {
                    NavigationRow(title: "Advanced",
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Sheet.self) { $0.destination }
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
    }

    // MARK: – Section builders

    @ViewBuilder
    private var dataSection: some View {
        Section("Data Settings") {
            NavigationRow(title: "Nightscout",
                          icon: "network")
            {
                settingsPath.value.append(Sheet.nightscout)
            }

            NavigationRow(title: "Dexcom",
                          icon: "sensor.tag.radiowaves.forward")
            {
                settingsPath.value.append(Sheet.dexcom)
            }
        }
    }

    // MARK: – Helpers

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
    case general, graph, tabs
    case infoDisplay
    case alarmsList, alarmSettings
    case remote
    case importExport
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
        case .tabs: TabSettingsView()
        case .infoDisplay: InfoDisplaySettingsView(viewModel: .init())
        case .alarmsList: AlarmListView()
        case .alarmSettings: AlarmSettingsView()
        case .remote: RemoteSettingsView(viewModel: .init())
        case .importExport: ImportExportSettingsView()
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
