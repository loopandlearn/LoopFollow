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
            webSocketSection

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

    @State private var showWebSocketInfo = false

    private var webSocketSection: some View {
        Section(header: webSocketSectionHeader) {
            Toggle("Enable WebSocket", isOn: $viewModel.webSocketEnabled)
            if viewModel.webSocketEnabled {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(viewModel.webSocketStatus)
                        .foregroundColor(viewModel.webSocketStatusColor)
                }
            }
        }
        .sheet(isPresented: $showWebSocketInfo) {
            NavigationStack {
                ScrollView {
                    Text("""
                    When enabled, LoopFollow maintains a live connection to your Nightscout server using WebSocket while the app is in the foreground. Data updates (new glucose readings, treatments, device status) arrive within seconds instead of waiting for the next polling cycle.

                    The WebSocket disconnects when LoopFollow moves to the background and reconnects when you return to the app. Polling continues to handle updates while the app is in the background.

                    In the foreground, polling continues at a reduced frequency as a safety net. If the WebSocket connection drops, normal polling resumes immediately.
                    """)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Real-time Updates")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showWebSocketInfo = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var webSocketSectionHeader: some View {
        HStack(spacing: 4) {
            Text("Real-time Updates")
            Button {
                showWebSocketInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
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
