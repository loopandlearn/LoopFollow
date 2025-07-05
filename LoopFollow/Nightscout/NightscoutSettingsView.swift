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
        Section {
            TextField("URL", text: $viewModel.nightscoutURL)
                .textContentType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: viewModel.nightscoutURL) { newValue in
                    viewModel.processURL(newValue)
                }
        } header: {
            Text("URL")
        }
    }

    private var tokenSection: some View {
        Section {
            TextField("Token", text: $viewModel.nightscoutToken)
                .textContentType(.password)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        } header: {
            Text("Token")
        }
    }

    private var statusSection: some View {
        Section {
            Text(viewModel.nightscoutStatus)
        } header: {
            Text("Status")
        }
    }
}
