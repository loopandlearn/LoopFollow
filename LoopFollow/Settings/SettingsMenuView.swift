// LoopFollow
// SettingsMenuView.swift
// Created by Jonas Björkert on 2025-05-26.

import SwiftUI
import UIKit

struct SettingsMenuView: View {
    // MARK: – Call-backs -----------------------------------------------------

    let onNightscoutVisibilityChange: (_ enabled: Bool) -> Void

    // MARK: – Local state ----------------------------------------------------

    @State private var sheet: Sheet?
    @State private var latestVersion: String?
    @State private var versionTint: Color = .secondary

    // MARK: – Body -----------------------------------------------------------

    var body: some View {
        NavigationStack {
            List {
                // ────────────── Data settings ──────────────
                dataSection

                // ────────────── App settings ──────────────
                Section("App Settings") {
                    navRow(title: "Background Refresh Settings",
                           icon: "arrow.clockwise",
                           destination: .backgroundRefresh)

                    navRow(title: "General Settings",
                           icon: "gearshape",
                           destination: .general)

                    navRow(title: "Graph Settings",
                           icon: "chart.xyaxis.line",
                           destination: .graph)

                    if IsNightscoutEnabled() {
                        navRow(title: "Information Display Settings",
                               icon: "info.circle",
                               destination: .infoDisplay)
                    }
                }

                // ────────────── Alarms ──────────────
                Section {
                    navRow(title: "Alarms",
                           icon: "bell",
                           destination: .alarmsList)

                    navRow(title: "Alarm Settings",
                           icon: "bell.badge",
                           destination: .alarmSettings)
                }

                // ────────────── Integrations ──────────────
                Section("Integrations") {
                    navRow(title: "Calendar",
                           icon: "calendar",
                           destination: .calendar)

                    navRow(title: "Contact",
                           icon: "person.circle",
                           destination: .contact)
                }

                // ────────────── Advanced / Logs ──────────────
                Section("Advanced Settings") {
                    navRow(title: "Advanced Settings",
                           icon: "exclamationmark.shield",
                           destination: .advanced)
                }

                Section("Logging") {
                    navRow(title: "View Log",
                           icon: "doc.text.magnifyingglass",
                           destination: .viewLog)

                    Button {
                        shareLogs()
                    } label: {
                        Label("Share Logs", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                }

                // ────────────── Community ──────────────
                Section("Community") {
                    Link(destination: URL(string: "https://www.facebook.com/groups/loopfollowlnl")!) {
                        Label("LoopFollow Facebook Group", systemImage: "person.3")
                    }
                }

                // ────────────── Build info ──────────────
                buildInfoSection
            }
            .navigationTitle("Settings")
        }
        .task { await refreshVersionInfo() }
        .sheet(item: $sheet) { $0.destination }
    }

    // MARK: – Section builders ----------------------------------------------

    /// “Data Settings”
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

            navRow(title: "Nightscout Settings",
                   icon: "network",
                   destination: .nightscout)

            navRow(title: "Dexcom Settings",
                   icon: "sensor.tag.radiowaves.forward",
                   destination: .dexcom)
        }
        .onAppear {
            onNightscoutVisibilityChange(IsNightscoutEnabled())
        }
    }

    /// version / build info
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
            keyValue("Built", dateTimeUtils.formattedDate(from: build.buildDate()))
            keyValue("Branch", build.branchAndSha)
        }
    }

    // MARK: – Row helpers ----------------------------------------------------

    /// Standard row with icon, chevron and sheet presentation
    /// One tappable row, styled like the iOS Settings app
    @ViewBuilder
    private func navRow(
        title: String,
        icon: String,
        tint: Color = .primary,
        destination: Sheet
    ) -> some View {
        Button {
            sheet = destination
        } label: {
            HStack {
                Glyph(symbol: icon, tint: tint)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Simple key-value row
    @ViewBuilder
    private func keyValue(_ key: String, _ value: String, tint: Color = .secondary) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundColor(tint)
        }
    }

    // MARK: – Version check --------------------------------------------------

    private func refreshVersionInfo() async {
        let manager = AppVersionManager()
        let (latest, newer, blacklisted) = await manager.checkForNewVersionAsync()
        latestVersion = latest ?? "Unknown"

        // match old colour logic
        let current = manager.version()
        versionTint = blacklisted ? .red :
            newer ? .orange :
            latest == current ? .green : .secondary
    }

    // MARK: – Share logs -----------------------------------------------------

    private func shareLogs() {
        let files = LogManager.shared.logFilesForTodayAndYesterday()
        guard !files.isEmpty else {
            UIApplication.shared.topMost?.presentSimpleAlert(
                title: "No Logs Available",
                message: "There are no logs to share."
            )
            return
        }
        let avc = UIActivityViewController(activityItems: files, applicationActivities: nil)
        UIApplication.shared.topMost?.present(avc, animated: true)
    }
}

// MARK: – Sheet routing identical to earlier -------------------------------

private enum Sheet: Identifiable {
    case nightscout, dexcom
    case backgroundRefresh
    case general, graph
    case infoDisplay
    case alarmsList, alarmSettings
    case remote
    case calendar, contact
    case advanced
    case viewLog

    var id: Int { hashValue }

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
        case .calendar: WatchSettingsView()
        case .contact: ContactSettingsView(viewModel: .init())
        case .advanced: AdvancedSettingsView(viewModel: .init())
        case .viewLog: LogView(viewModel: .init())
        }
    }
}

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
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

struct Glyph: View {
    let symbol: String
    let tint: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .systemGray))
                .frame(width: 28, height: 28)

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(tint)
        }
        .frame(width: 36, height: 36)
    }
}
