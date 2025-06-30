// LoopFollow
// DexcomSettingsView.swift
// Created by Jonas Björkert.

import SwiftUI

struct DexcomSettingsView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dexcom Settings")) {
                    TextField("User Name", text: $viewModel.userName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("Password", text: $viewModel.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Picker("Server", selection: $viewModel.server) {
                        Text("US").tag("US")
                        Text("NON-US").tag("NON-US")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .navigationBarTitle("Dexcom Settings", displayMode: .inline)
    }
}
