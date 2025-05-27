// LoopFollow
// DexcomSettingsView.swift
// Created by Jonas Björkert on 2025-01-18.

import SwiftUI

struct DexcomSettingsView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

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
            .navigationBarTitle("Dexcom Settings", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }
}
