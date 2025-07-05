// LoopFollow
// InfoDisplaySettingsView.swift
// Created by Jonas Björkert.

import SwiftUI

struct InfoDisplaySettingsView: View {
    @ObservedObject var viewModel: InfoDisplaySettingsViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle(isOn: Binding(
                        get: { Storage.shared.hideInfoTable.value },
                        set: { Storage.shared.hideInfoTable.value = $0 }
                    )) {
                        Text("Hide Information Table")
                    }
                }

                Section(header: Text("Information Display Settings")) {
                    List {
                        ForEach(viewModel.infoSort, id: \.self) { sortedIndex in
                            HStack {
                                Text(viewModel.getName(for: sortedIndex))
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { viewModel.infoVisible[sortedIndex] },
                                    set: { _ in
                                        viewModel.toggleVisibility(for: sortedIndex)
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                        .onMove(perform: viewModel.move)
                    }
                    .environment(\.editMode, .constant(.active))
                }
            }
            .onDisappear {
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .navigationBarTitle("Information Display Settings", displayMode: .inline)
    }
}
