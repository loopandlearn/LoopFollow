// LoopFollow
// NightscoutSettingsView.swift

import SwiftUI

struct NightscoutSettingsView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel

    var body: some View {
        NavigationView {
            Form {
                urlSection
                tokenSection
                statusSection
                webSocketSection
                importSection
            }
            .onDisappear {
                viewModel.dismiss()
            }
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
                    When enabled, LoopFollow maintains a live connection to your Nightscout server using WebSocket. This allows data updates (new glucose readings, treatments, device status) to arrive within seconds instead of waiting for the next polling cycle.

                    Polling continues at reduced frequency as a safety net. If the WebSocket connection drops, normal polling resumes immediately.

                    This feature may affect battery usage. On WiFi, impact is minimal. On cellular, the persistent connection may prevent the radio from entering idle mode.
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
