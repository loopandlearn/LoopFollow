// LoopFollow
// NightscoutSettingsView.swift

import SwiftUI

struct NightscoutSettingsView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel

    var body: some View {
        Form {
            urlSection
            tokenSection
            statusSection
            importSection
        }
        .onDisappear {
            viewModel.dismiss()
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Nightscout Settings", displayMode: .inline)
    }

    // MARK: - Subviews / Computed Properties

    private var urlSection: some View {
        Section {
            TextField("Enter URL", text: $viewModel.nightscoutURL)
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: viewModel.nightscoutURL) { newValue in
                    viewModel.processURL(newValue)
                }
        } header: {
            Label("URL", systemImage: "globe")
        } footer: {
            Text("Enter your Nightscout site URL (e.g., https://yoursite.herokuapp.com or https://yoursite.ns.10be.de).")
        }
    }

    private var tokenSection: some View {
        Section {
            HStack {
                Text("Access Token")
                TogglableSecureInput(
                    placeholder: "Enter Token",
                    text: $viewModel.nightscoutToken,
                    style: .singleLine,
                    textContentType: .password
                )
            }
        } header: {
            Label("Token", systemImage: "key")
        } footer: {
            Text("Optional: Enter an access token if your Nightscout site requires authentication.")
        }
    }

    private var statusSection: some View {
        Section {
            Text(viewModel.nightscoutStatus)
        } header: {
            Label("Status", systemImage: "checkmark.circle")
        }
    }

    private var importSection: some View {
        Section {
            NavigationLink(destination: ImportExportSettingsView()) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.blue)
                    Text("Import Settings from QR Code")
                }
            }
        } header: {
            Label("Import Settings", systemImage: "square.and.arrow.down")
        }
    }
}
