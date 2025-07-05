// LoopFollow
// NightscoutSettingsView.swift
// Created by Jonas Björkert.

import SwiftUI

struct NightscoutSettingsView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel

    var body: some View {
        NavigationView {
            Form {
                urlSection
                tokenSection
                statusSection
            }
            .onDisappear {
                viewModel.dismiss()
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .navigationBarTitle("Nightscout Settings", displayMode: .inline)
    }

    // MARK: - Subviews / Computed Properties

    private var urlSection: some View {
        Section(header: Text("URL")) {
            TextField("Enter URL", text: $viewModel.nightscoutURL)
                .textContentType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: viewModel.nightscoutURL) { newValue in
                    viewModel.processURL(newValue)
                }
        }
    }

    private var tokenSection: some View {
        Section(header: Text("Token")) {
            HStack {
                Text("Access Token")
                TogglableSecureInput(
                    placeholder: "Enter Token",
                    text: $viewModel.nightscoutToken,
                    style: .singleLine
                )
            }
        }
    }

    private var statusSection: some View {
        Section(header: Text("Status")) {
            Text(viewModel.nightscoutStatus)
        }
    }
}
