// LoopFollow
// TabCustomizationSettingsView.swift
// Created by Jonas Björkert.

import SwiftUI

struct TabCustomizationSettingsView: View {
    @ObservedObject var tab2Selection = Storage.shared.tab2Selection
    @ObservedObject var tab4Selection = Storage.shared.tab4Selection

    var body: some View {
        Form {
            Section("Tab Customization") {
                Picker("Tab 2", selection: $tab2Selection.value) {
                    ForEach(TabSelection.allCases, id: \.self) { selection in
                        Text(selection.displayName).tag(selection)
                    }
                }

                Picker("Tab 4", selection: $tab4Selection.value) {
                    ForEach(TabSelection.allCases, id: \.self) { selection in
                        Text(selection.displayName).tag(selection)
                    }
                }
            }

            Section {
                Text("Note: Home (Tab 1), Snoozer (Tab 3), and Settings (Tab 5) cannot be changed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationBarTitle("Tab Settings", displayMode: .inline)
    }
}
