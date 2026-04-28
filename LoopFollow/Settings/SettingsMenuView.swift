// LoopFollow
// SettingsMenuView.swift

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    // MARK: - Observed Objects

    @ObservedObject private var nightscoutURL = Storage.shared.url

    // MARK: – Local state

    var onBack: (() -> Void)?

    // MARK: – Observed objects

    @ObservedObject private var url = Storage.shared.url

    // MARK: – Body

    var body: some View {
        List {
            dataSection

            Section("Display Settings") {
                NavigationRow(title: "General",
                              icon: "gearshape",
                              value: SettingsRoute.general)
                NavigationRow(title: "Graph",
                              icon: "chart.xyaxis.line",
                              value: SettingsRoute.graph)

                if !nightscoutURL.value.isEmpty {
                    NavigationRow(title: "Information Display",
                                  icon: "info.circle",
                                  value: SettingsRoute.infoDisplay)
                }

                NavigationRow(title: "Tabs",
                              icon: "rectangle.3.group",
                              value: SettingsRoute.tabSettings)
            }

            Section("App Settings") {
                NavigationRow(title: "Background Refresh",
                              icon: "arrow.clockwise",
                              value: SettingsRoute.backgroundRefresh)

                NavigationRow(title: "Import/Export",
                              icon: "square.and.arrow.down",
                              value: SettingsRoute.importExport)

                NavigationRow(title: "APN",
                              icon: "bell.and.waves.left.and.right",
                              value: SettingsRoute.apn)

                #if !targetEnvironment(macCatalyst)
                    NavigationRow(title: "Live Activity",
                                  icon: "dot.radiowaves.left.and.right",
                                  value: SettingsRoute.liveActivity)
                #endif

                if !nightscoutURL.value.isEmpty {
                    NavigationRow(title: "Remote",
                                  icon: "antenna.radiowaves.left.and.right",
                                  value: SettingsRoute.remote)
                }
            }

            Section("Alarms") {
                NavigationRow(title: "Alarms",
                              icon: "bell.badge",
                              value: SettingsRoute.alarmSettings)
            }

            Section("Integrations") {
                NavigationRow(title: "Calendar",
                              icon: "calendar",
                              value: SettingsRoute.calendar)

                NavigationRow(title: "Contact",
                              icon: "person.circle",
                              value: SettingsRoute.contact)
            }

            Section("Advanced Settings") {
                NavigationRow(title: "Advanced",
                              icon: "exclamationmark.shield",
                              value: SettingsRoute.advanced)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
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
                          icon: "network",
                          value: SettingsRoute.nightscout)

            NavigationRow(title: "Dexcom",
                          icon: "sensor.tag.radiowaves.forward",
                          value: SettingsRoute.dexcom)
        }
    }
}

// MARK: – Sheet routing

enum SettingsRoute: Hashable, Identifiable {
    case settings
    case nightscout, dexcom
    case backgroundRefresh
    case general, graph
    case tabSettings
    case infoDisplay
    case alarmSettings
    case apn
    #if !targetEnvironment(macCatalyst)
        case liveActivity
    #endif
    case remote
    case importExport
    case calendar, contact
    case advanced
    case aggregatedStats

    var id: Self { self }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .settings: SettingsMenuView()
        case .nightscout: NightscoutSettingsView(viewModel: .init())
        case .dexcom: DexcomSettingsView(viewModel: .init())
        case .backgroundRefresh: BackgroundRefreshSettingsView(viewModel: .init())
        case .general: GeneralSettingsView()
        case .graph: GraphSettingsView()
        case .tabSettings: TabCustomizationModal()
        case .infoDisplay: InfoDisplaySettingsView(viewModel: .init())
        case .alarmSettings: AlarmSettingsView()
        case .apn: APNSettingsView()
        #if !targetEnvironment(macCatalyst)
            case .liveActivity: LiveActivitySettingsView()
        #endif
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
        MainViewController.shared
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
