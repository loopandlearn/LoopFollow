// LoopFollow
// TabCustomizationModal.swift

import SwiftUI
import UIKit

struct TabSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Local state for editing
    @State private var alarmsPosition: TabPosition
    @State private var remotePosition: TabPosition
    @State private var nightscoutPosition: TabPosition
    @State private var hasChanges = false

    // Store original values to detect changes
    private let originalAlarmsPosition: TabPosition
    private let originalRemotePosition: TabPosition
    private let originalNightscoutPosition: TabPosition

    init() {
        let currentAlarms = Storage.shared.alarmsPosition.value
        let currentRemote = Storage.shared.remotePosition.value
        let currentNightscout = Storage.shared.nightscoutPosition.value

        _alarmsPosition = State(initialValue: currentAlarms)
        _remotePosition = State(initialValue: currentRemote)
        _nightscoutPosition = State(initialValue: currentNightscout)

        originalAlarmsPosition = currentAlarms
        originalRemotePosition = currentRemote
        originalNightscoutPosition = currentNightscout
    }

    var body: some View {
        Form {
            Section("Tab Positions") {
                TabPositionRow(
                    title: "Alarms",
                    icon: "alarm",
                    position: $alarmsPosition,
                    otherPositions: [remotePosition, nightscoutPosition]
                )
                .onChange(of: alarmsPosition) { _ in checkForChanges() }

                TabPositionRow(
                    title: "Remote",
                    icon: "antenna.radiowaves.left.and.right",
                    position: $remotePosition,
                    otherPositions: [alarmsPosition, nightscoutPosition]
                )
                .onChange(of: remotePosition) { _ in checkForChanges() }

                TabPositionRow(
                    title: "Nightscout",
                    icon: "safari",
                    position: $nightscoutPosition,
                    otherPositions: [alarmsPosition, remotePosition]
                )
                .onChange(of: nightscoutPosition) { _ in checkForChanges() }
            }

            Section {
                Text("• Tab 2 and Tab 4 can each hold one item")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Items in 'More Menu' appear under the last tab")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Hidden items are not accessible")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if hasChanges {
                Section {
                    Button("Apply Changes") {
                        applyChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    private func checkForChanges() {
        hasChanges = alarmsPosition != originalAlarmsPosition ||
            remotePosition != originalRemotePosition ||
            nightscoutPosition != originalNightscoutPosition
    }

    private func applyChanges() {
        Storage.shared.alarmsPosition.value = alarmsPosition
        Storage.shared.remotePosition.value = remotePosition
        Storage.shared.nightscoutPosition.value = nightscoutPosition

        dismiss()

        // Handle tab reorganization after dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            handleTabReorganization()
        }
    }

    private func handleTabReorganization() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }

        var tabBarController: UITabBarController?
        if let tbc = rootVC as? UITabBarController {
            tabBarController = tbc
        } else if let nav = rootVC as? UINavigationController,
                  let tbc = nav.viewControllers.first as? UITabBarController
        {
            tabBarController = tbc
        }

        guard let tabBar = tabBarController else { return }

        if let presented = tabBar.presentedViewController {
            presented.dismiss(animated: false) {
                tabBar.selectedIndex = 0
            }
        } else {
            tabBar.selectedIndex = 0
        }
    }
}

struct TabPositionRow: View {
    let title: String
    let icon: String
    @Binding var position: TabPosition
    let otherPositions: [TabPosition]

    var availablePositions: [TabPosition] {
        TabPosition.allCases.filter { tabPosition in
            // Always allow current position and disabled/more
            if tabPosition == position || tabPosition == .more || tabPosition == .disabled {
                return true
            }
            // Otherwise, only allow if not taken by another position
            return !otherPositions.contains(tabPosition)
        }
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.accentColor)

            Text(title)

            Spacer()

            Picker(title, selection: $position) {
                ForEach(availablePositions, id: \.self) { pos in
                    Text(pos.displayName).tag(pos)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}
