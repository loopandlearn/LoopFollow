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
        Section(header: Text("URL")) {
            TextField("Enter URL", text: $viewModel.nightscoutURL)
                .textContentType(.username)
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
                    style: .singleLine,
                    textContentType: .password
                )
            }
        }
    }

    private var statusSection: some View {
        Section(header: Text("Status")) {
            Text(viewModel.nightscoutStatus)
        }
    }

    private var importSection: some View {
        Section(header: Text("Import Settings")) {
            NavigationLink(destination: ImportExportSettingsView()) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                    Text("Import Settings from QR Code")
                }
            }
        }
    }
}
