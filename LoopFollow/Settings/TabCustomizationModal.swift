// LoopFollow
// TabCustomizationModal.swift
// Created by Jonas Björkert.

import SwiftUI

struct TabCustomizationModal: View {
    @Binding var isPresented: Bool
    let onApply: () -> Void

    // Local state for editing
    @State private var alarmsPosition: TabPosition
    @State private var remotePosition: TabPosition
    @State private var nightscoutPosition: TabPosition
    @State private var hasChanges = false

    // Store original values to detect changes
    private let originalAlarmsPosition: TabPosition
    private let originalRemotePosition: TabPosition
    private let originalNightscoutPosition: TabPosition

    init(isPresented: Binding<Bool>, onApply: @escaping () -> Void) {
        _isPresented = isPresented
        self.onApply = onApply

        // Initialize with current values
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
        NavigationView {
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
                        Text("Changes will be applied when you tap 'Apply'")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Tab Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }

    private func checkForChanges() {
        hasChanges = alarmsPosition != originalAlarmsPosition ||
            remotePosition != originalRemotePosition ||
            nightscoutPosition != originalNightscoutPosition
    }

    private func applyChanges() {
        // Save the new positions
        Storage.shared.alarmsPosition.value = alarmsPosition
        Storage.shared.remotePosition.value = remotePosition
        Storage.shared.nightscoutPosition.value = nightscoutPosition

        // Dismiss the modal
        isPresented = false

        // Call the completion handler after a small delay to ensure modal is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onApply()
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
