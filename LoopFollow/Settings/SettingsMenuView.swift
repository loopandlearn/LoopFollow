// LoopFollow
// SettingsMenuView.swift

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    // MARK: - Observed Objects

    @ObservedObject private var nightscoutURL = Storage.shared.url
    @ObservedObject private var settingsPath = Observable.shared.settingsPath

    // MARK: – Local state

    var onBack: (() -> Void)?

    // MARK: – Observed objects

    @ObservedObject private var url = Storage.shared.url

    // MARK: – Body

    var body: some View {
        NavigationStack(path: $settingsPath.value) {
            List {
                dataSection

                Section("Display Settings") {
                    NavigationRow(title: "General",
                                  icon: "gearshape")
                    {
                        settingsPath.value.append(Sheet.general)
                    }
                    NavigationRow(title: "Graph",
                                  icon: "chart.xyaxis.line")
                    {
                        settingsPath.value.append(Sheet.graph)
                    }

                    if !nightscoutURL.value.isEmpty {
                        NavigationRow(title: "Information Display",
                                      icon: "info.circle")
                        {
                            settingsPath.value.append(Sheet.infoDisplay)
                        }
                    }

                    NavigationRow(title: "Tabs",
                                  icon: "rectangle.3.group")
                    {
                        settingsPath.value.append(Sheet.tabSettings)
                    }
                }

                Section("App Settings") {
                    NavigationRow(title: "Background Refresh",
                                  icon: "arrow.clockwise")
                    {
                        settingsPath.value.append(Sheet.backgroundRefresh)
                    }

                    NavigationRow(title: "Import/Export",
                                  icon: "square.and.arrow.down")
                    {
                        settingsPath.value.append(Sheet.importExport)
                    }

                    NavigationRow(title: "APN",
                                  icon: "bell.and.waves.left.and.right")
                    {
                        settingsPath.value.append(Sheet.apn)
                    }

                    NavigationRow(title: "Live Activity",
                                  icon: "dot.radiowaves.left.and.right")
                    {
                        settingsPath.value.append(Sheet.liveActivity)
                    }

                    if !nightscoutURL.value.isEmpty {
                        NavigationRow(title: "Remote",
                                      icon: "antenna.radiowaves.left.and.right")
                        {
                            settingsPath.value.append(Sheet.remote)
                        }
                    }
                }

                Section("Alarms") {
                    NavigationRow(title: "Alarms",
                                  icon: "bell.badge")
                    {
                        settingsPath.value.append(Sheet.alarmSettings)
                    }
                }

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

                Section("Advanced Settings") {
                    NavigationRow(title: "Advanced",
                                  icon: "exclamationmark.shield")
                    {
                        settingsPath.value.append(Sheet.advanced)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Sheet.self) { $0.destination }
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBack) {
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
            Picker("Units",
                   selection: Binding(
                       get: { Storage.shared.units.value },
                       set: { Storage.shared.units.value = $0 }
                   )) {
                Text("mg/dL").tag("mg/dL")
                Text("mmol/L").tag("mmol/L")
            }
            .pickerStyle(.segmented)

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
}

// MARK: – Sheet routing

private enum Sheet: Hashable, Identifiable {
    case nightscout, dexcom
    case backgroundRefresh
    case general, graph
    case tabSettings
    case infoDisplay
    case alarmSettings
    case apn
    case liveActivity
    case remote
    case importExport
    case calendar, contact
    case advanced
    case aggregatedStats

    var id: Self { self }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .nightscout: NightscoutSettingsView(viewModel: .init())
        case .dexcom: DexcomSettingsView(viewModel: .init())
        case .backgroundRefresh: BackgroundRefreshSettingsView(viewModel: .init())
        case .general: GeneralSettingsView()
        case .graph: GraphSettingsView()
        case .tabSettings: TabCustomizationModal()
        case .infoDisplay: InfoDisplaySettingsView(viewModel: .init())
        case .alarmSettings: AlarmSettingsView()
        case .apn: APNSettingsView()
        case .liveActivity: LiveActivitySettingsView()
        case .remote: RemoteSettingsView(viewModel: .init())
        case .importExport: ImportExportSettingsView()
        case .calendar: CalendarSettingsView()
        case .contact: ContactSettingsView(viewModel: .init())
        case .advanced: AdvancedSettingsView(viewModel: .init())
        case .aggregatedStats:
            AggregatedStatsViewWrapper()
        }
    }
}

// Helper view to access MainViewController
struct AggregatedStatsViewWrapper: View {
    @State private var mainViewController: MainViewController?

    var body: some View {
        Group {
            if let mainVC = mainViewController {
                AggregatedStatsContentView(mainViewController: mainVC)
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
