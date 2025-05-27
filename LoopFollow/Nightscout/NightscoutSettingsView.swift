// LoopFollow
// NightscoutSettingsView.swift
// Created by Jonas Björkert on 2025-01-18.

import SwiftUI

struct NightscoutSettingsView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                urlSection
                tokenSection
                statusSection
            }
            .navigationBarTitle("Nightscout Settings", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onDisappear {
                viewModel.dismiss()
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
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
