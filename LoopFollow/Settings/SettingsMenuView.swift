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

/// A single setting inside a settings screen, exposed to Menu search. Leaves
/// are not navigable on their own — a search hit opens the screen
/// (`SettingsRoute`) that contains it.
struct SettingsLeaf: Hashable {
    let title: String
    let keywords: [String]

    init(_ title: String, _ keywords: [String] = []) {
        self.title = title
        self.keywords = keywords
    }
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
        #if !targetEnvironment(macCatalyst)
            case .liveActivity: return ["dynamic island", "lock screen"]
        #endif
        case .importExport: return ["import", "export", "backup"]
        default: return []
        }
    }

    /// The individual settings inside this screen, so Menu search can find a
    /// bottom-level setting (e.g. "Graph Basal") and open the screen containing
    /// it. Titles mirror the row (or section) titles in each screen's view —
    /// keep them in sync when adding or renaming rows.
    var leaves: [SettingsLeaf] {
        switch self {
        case .nightscout: return [
                SettingsLeaf("URL"),
                SettingsLeaf("Access Token", ["token"]),
                SettingsLeaf("Enable WebSocket", ["websocket", "real-time"]),
            ]
        case .dexcom: return [
                SettingsLeaf("User Name", ["username"]),
                SettingsLeaf("Password"),
                SettingsLeaf("Server"),
            ]
        case .general: return [
                SettingsLeaf("Display App Badge", ["badge"]),
                SettingsLeaf("Persistent Notification"),
                SettingsLeaf("Appearance", ["dark mode", "light mode", "theme"]),
                SettingsLeaf("Display Stats"),
                SettingsLeaf("Display Small Graph"),
                SettingsLeaf("Color BG Text"),
                SettingsLeaf("Keep Screen Active", ["screen lock", "screenlock"]),
                SettingsLeaf("Show Display Name"),
                SettingsLeaf("Snoozer emoji"),
                SettingsLeaf("Force portrait mode", ["orientation", "landscape"]),
                SettingsLeaf("Time Zone Override", ["timezone"]),
                SettingsLeaf("Speak BG", ["voice", "speech"]),
                SettingsLeaf("Send anonymous usage stats", ["telemetry", "diagnostics"]),
            ]
        case .graph: return [
                SettingsLeaf("Display Dots"),
                SettingsLeaf("Display Lines"),
                SettingsLeaf("Show DIA Lines", ["dia"]),
                SettingsLeaf("Show −30 min Line", ["-30"]),
                SettingsLeaf("Show −90 min Line", ["-90"]),
                SettingsLeaf("Show Yesterday's BG", ["yesterday"]),
                SettingsLeaf("Show Midnight Lines"),
                SettingsLeaf("Show Carb/Bolus Values", ["carbs"]),
                SettingsLeaf("Show Carb Absorption"),
                SettingsLeaf("Treatments on Small Graph"),
                SettingsLeaf("Small Graph Height", ["height"]),
                SettingsLeaf("Hours of Prediction", ["prediction"]),
                SettingsLeaf("Prediction Style"),
                SettingsLeaf("Min Basal", ["basal scale"]),
                SettingsLeaf("Min BG Scale"),
                SettingsLeaf("Show Days Back", ["history", "days back"]),
            ]
        case .infoDisplay:
            return [SettingsLeaf("Hide Information Table")]
                + InfoType.allCases.map { SettingsLeaf($0.name) }
        case .units: return [
                SettingsLeaf("Glucose Unit"),
                SettingsLeaf("Range Mode", ["tir", "titr", "time in range"]),
                SettingsLeaf("Glycemic Metrics", ["hba1c", "ehba1c", "gmi"]),
                SettingsLeaf("Variability", ["standard deviation", "cv"]),
            ]
        case .backgroundRefresh: return [
                SettingsLeaf("Background Refresh Type", ["silent tune", "bluetooth", "rileylink", "omnipod", "heartbeat"]),
            ]
        case .importExport: return [
                SettingsLeaf("Scan QR Code to Import Settings", ["qr"]),
                SettingsLeaf("Export Settings To QR Code", ["qr"]),
            ]
        case .apn: return [
                SettingsLeaf("APNS Key ID", ["apns"]),
                SettingsLeaf("APNS Key", ["apns", "p8"]),
            ]
        #if !targetEnvironment(macCatalyst)
            case .liveActivity: return [
                    SettingsLeaf("Enable Live Activity"),
                    SettingsLeaf("Restart Live Activity"),
                    SettingsLeaf("Grid Slots", ["carplay", "watch"]),
                ]
        #endif
        case .remote: return [
                SettingsLeaf("Loop Remote Control"),
                SettingsLeaf("Trio Remote Control", ["trc"]),
                SettingsLeaf("Meal with Bolus"),
                SettingsLeaf("Meal with Fat/Protein"),
                SettingsLeaf("Guardrails", ["max bolus", "max carbs", "max fat", "max protein"]),
                SettingsLeaf("Bolus Increment"),
                SettingsLeaf("Shared Secret"),
                SettingsLeaf("QR Code URL", ["qr"]),
            ]
        case .alarmSettings: return [
                SettingsLeaf("All Alerts Snoozed", ["snooze all"]),
                SettingsLeaf("All Sounds Muted", ["mute all"]),
                SettingsLeaf("Day starts", ["schedule", "day/night"]),
                SettingsLeaf("Night starts", ["schedule", "day/night"]),
                SettingsLeaf("Override System Volume", ["volume"]),
                SettingsLeaf("Audio During Calls"),
                SettingsLeaf("Ignore Zero BG"),
                SettingsLeaf("Auto-Snooze CGM Start", ["autosnooze"]),
                SettingsLeaf("Volume Buttons Snooze Alarms"),
            ]
        case .calendar: return [
                SettingsLeaf("Save BG to Calendar", ["watch", "carplay"]),
                SettingsLeaf("Calendar Text"),
            ]
        case .contact: return [
                SettingsLeaf("Enable Contact BG Updates", ["watch face"]),
                SettingsLeaf("Background Color"),
                SettingsLeaf("Color Mode"),
                SettingsLeaf("Text Color"),
                SettingsLeaf("Show Trend"),
                SettingsLeaf("Show Delta"),
                SettingsLeaf("Show IOB"),
            ]
        case .advanced: return [
                SettingsLeaf("Download Treatments"),
                SettingsLeaf("Download Prediction"),
                SettingsLeaf("Graph Basal"),
                SettingsLeaf("Graph Bolus"),
                SettingsLeaf("Graph Carbs"),
                SettingsLeaf("Graph Other Treatments"),
                SettingsLeaf("BG Update Delay", ["delay"]),
                SettingsLeaf("Debug Log Level", ["logging"]),
            ]
        case .tabSettings, .settings, .aggregatedStats: return []
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
