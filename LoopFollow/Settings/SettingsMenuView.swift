// LoopFollow
// SettingsMenuView.swift

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    @ObservedObject private var nightscoutURL = Storage.shared.url

    var body: some View {
        List {
            ForEach(SettingsRoute.menuSections(nightscoutConfigured: !nightscoutURL.value.isEmpty), id: \.0) { section, routes in
                Section(section.rawValue) {
                    ForEach(routes) { route in
                        NavigationRow(title: route.title,
                                      icon: route.icon,
                                      value: route)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: – Sheet routing

enum SettingsSection: String, CaseIterable, Hashable {
    case data = "Data Settings"
    case display = "Display Settings"
    case app = "App Settings"
    case alarms = "Alarms"
    case integrations = "Integrations"
    case advanced = "Advanced Settings"
}

enum SettingsRoute: Hashable, Identifiable {
    case settings
    case units
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

    // MARK: – Row presentation (single source of truth)

    /// Title shown in the Settings list and used for search matching.
    /// Non-row cases (`.settings`, `.aggregatedStats`) return "" and are never
    /// included in `menuSections`.
    var title: String {
        switch self {
        case .nightscout: return "Nightscout"
        case .dexcom: return "Dexcom"
        case .general: return "General"
        case .graph: return "Graph"
        case .infoDisplay: return "Information Display"
        case .units: return "Units and Metrics"
        case .tabSettings: return "Tabs"
        case .backgroundRefresh: return "Background Refresh"
        case .importExport: return "Import/Export"
        case .apn: return "APN"
        #if !targetEnvironment(macCatalyst)
            case .liveActivity: return "Live Activity"
        #endif
        case .remote: return "Remote"
        case .alarmSettings: return "Alarms"
        case .calendar: return "Calendar"
        case .contact: return "Contact"
        case .advanced: return "Advanced"
        case .settings, .aggregatedStats: return ""
        }
    }

    var icon: String {
        switch self {
        case .nightscout: return "network"
        case .dexcom: return "sensor.tag.radiowaves.forward"
        case .general: return "gearshape"
        case .graph: return "chart.xyaxis.line"
        case .infoDisplay: return "info.circle"
        case .units: return "scalemass"
        case .tabSettings: return "rectangle.3.group"
        case .backgroundRefresh: return "arrow.clockwise"
        case .importExport: return "square.and.arrow.down"
        case .apn: return "bell.and.waves.left.and.right"
        #if !targetEnvironment(macCatalyst)
            case .liveActivity: return "dot.radiowaves.left.and.right"
        #endif
        case .remote: return "antenna.radiowaves.left.and.right"
        case .alarmSettings: return "bell.badge"
        case .calendar: return "calendar"
        case .contact: return "person.circle"
        case .advanced: return "exclamationmark.shield"
        case .settings, .aggregatedStats: return ""
        }
    }

    /// Extra synonyms so search finds a page by related terms, not just its title.
    var keywords: [String] {
        switch self {
        case .graph: return ["chart"]
        case .units: return ["mmol", "mgdl", "metrics"]
        case .infoDisplay: return ["info"]
        case .apn: return ["push", "notification"]
        case .liveActivity: return ["dynamic island", "lock screen"]
        case .importExport: return ["import", "export", "backup"]
        default: return []
        }
    }

    /// Ordered, grouped list of the routes shown as rows in the Settings menu.
    /// Encodes the conditional visibility in one place so both the list and the
    /// Menu search stay in sync.
    static func menuSections(nightscoutConfigured: Bool) -> [(SettingsSection, [SettingsRoute])] {
        var display: [SettingsRoute] = [.general, .graph]
        if nightscoutConfigured {
            display.append(.infoDisplay)
        }
        display += [.units, .tabSettings]

        var app: [SettingsRoute] = [.backgroundRefresh, .importExport, .apn]
        #if !targetEnvironment(macCatalyst)
            app.append(.liveActivity)
        #endif
        if nightscoutConfigured {
            app.append(.remote)
        }

        return [
            (.data, [.nightscout, .dexcom]),
            (.display, display),
            (.app, app),
            (.alarms, [.alarmSettings]),
            (.integrations, [.calendar, .contact]),
            (.advanced, [.advanced]),
        ]
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .settings: SettingsMenuView()
        case .units: UnitsSettingsView()
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
        // `keyWindow` is deprecated and returns nil on Mac Catalyst / multi-window iPad.
        // Walk connected scenes instead and prefer the foreground-active one.
        let windowScenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = windowScenes.first { $0.activationState == .foregroundActive }
            ?? windowScenes.first
        let rootVC = activeScene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? activeScene?.windows.first?.rootViewController
        guard var top = rootVC else { return nil }
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
