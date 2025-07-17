// LoopFollow
// TabCustomizationSettingsView.swift
// Created by Jonas Björkert.

import SwiftUI

struct TabCustomizationSettingsView: View {
    // MARK: - Local State

    @State private var alarmsPosition: TabPosition
    @State private var remotePosition: TabPosition
    @State private var nightscoutPosition: TabPosition

    init() {
        _alarmsPosition = State(initialValue: Storage.shared.alarmsPosition.value)
        _remotePosition = State(initialValue: Storage.shared.remotePosition.value)
        _nightscoutPosition = State(initialValue: Storage.shared.nightscoutPosition.value)
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

                TabPositionRow(
                    title: "Remote",
                    icon: "antenna.radiowaves.left.and.right",
                    position: $remotePosition,
                    otherPositions: [alarmsPosition, nightscoutPosition]
                )

                TabPositionRow(
                    title: "Nightscout",
                    icon: "safari",
                    position: $nightscoutPosition,
                    otherPositions: [alarmsPosition, remotePosition]
                )
            }

            Section {
                Text("• Tab 2 and Tab 4 can each hold one item")
                Text("• Items in 'More Menu' appear under the last tab")
                Text("• Hidden items are not accessible")
            }
        }
        .navigationTitle("Tab Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Storage.shared.alarmsPosition.value = alarmsPosition
            Storage.shared.remotePosition.value = remotePosition
            Storage.shared.nightscoutPosition.value = nightscoutPosition
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
