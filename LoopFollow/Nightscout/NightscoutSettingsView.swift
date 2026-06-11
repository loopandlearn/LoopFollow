// LoopFollow
// NightscoutSettingsView.swift

import SwiftUI

struct NightscoutSettingsView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel
    var usesModalCloseButton: Bool = false
    var onContinueToUnits: (() -> Void)? = nil
    var onImportSettings: (() -> Void)? = nil
    @State private var showUnitsSetup = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            urlSection
            tokenSection
            statusSection

            if viewModel.isFreshSetup {
                continueSection
            }

            importSection
        }
        .navigationDestination(isPresented: $showUnitsSetup) {
            UnitsOnboardingView {
                dismiss()
            }
        }
        .navigationBarTitle("Nightscout Settings", displayMode: .inline)
        .navigationBarBackButtonHidden(usesModalCloseButton)
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
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
            HStack {
                Text(viewModel.nightscoutStatus)
                if viewModel.isConnected {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
    }

    private var continueSection: some View {
        Section {
            Button(action: {
                if let onContinueToUnits {
                    onContinueToUnits()
                } else {
                    showUnitsSetup = true
                }
            }) {
                HStack {
                    Spacer()
                    Text("Continue")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isConnected)
            .listRowBackground(Color.clear)
        }
    }

    private var importSection: some View {
        Section(header: Text("Import Settings")) {
            if let onImportSettings {
                Button(action: onImportSettings) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                        Text("Import Settings from QR Code")
                            .foregroundColor(.primary)
                    }
                }
            } else {
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
}
