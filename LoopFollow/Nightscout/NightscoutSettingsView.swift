// LoopFollow
// NightscoutSettingsView.swift

import SwiftUI

struct NightscoutSettingsView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel
    var usesModalCloseButton: Bool = false
    var onContinueToUnits: (() -> Void)? = nil
    var onImportSettings: (() -> Void)? = nil
    @State private var showUnitsSetup = false
    @State private var activeInfoSheet: InfoSheet?
    @Environment(\.dismiss) private var dismiss

    private enum InfoSheet: Identifiable {
        case url, token
        var id: Self { self }
    }

    var body: some View {
        Form {
            urlSection
            tokenSection
            statusSection

            if viewModel.isFreshSetup {
                continueSection
            }

            webSocketSection
            importSection
        }
        .sheet(item: $activeInfoSheet) { sheet in
            switch sheet {
            case .url: urlInfoSheet
            case .token: tokenInfoSheet
            }
        }
        .navigationDestination(isPresented: $showUnitsSetup) {
            UnitsOnboardingView {
                dismiss()
            }
        }
        .onDisappear {
            viewModel.dismiss()
        }
        .navigationBarTitle("Nightscout Settings", displayMode: .inline)
        .navigationBarBackButtonHidden(usesModalCloseButton)
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    // MARK: - Sections

    private var urlSection: some View {
        Section(header: sectionHeader("URL", sheet: .url)) {
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
        Section(header: sectionHeader("Token", sheet: .token)) {
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

    // MARK: - Section Header

    private func sectionHeader(_ title: String, sheet: InfoSheet) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                activeInfoSheet = sheet
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Info Sheets

    private var urlInfoSheet: some View {
        NavigationStack {
            ScrollView {
                Text(verbatim: """
                Enter your Nightscout site URL, for example:
                https://yoursite.yourprovider.com

                You can copy your full URL (including the token) from Nightscout Admin Tools. When pasted here, LoopFollow automatically extracts both the URL and the token.

                To find your URL, open your Nightscout site in a browser and copy the address from the address bar. Remove any trailing slashes or path components — just the base URL is needed.
                """)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Nightscout URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { activeInfoSheet = nil }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var tokenInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("""
                    A token controls what LoopFollow can access on your Nightscout site. Tokens are not the same as API keys — they are created within Nightscout itself.
                    """)

                    Text("Creating a Token")
                        .font(.headline)
                    Text("""
                    1. Open your Nightscout site in a browser
                    2. Go to the hamburger menu (☰) and select Admin Tools
                    3. Under "Subjects", tap "Add new Subject"
                    4. Enter a name (e.g. "LoopFollow") and select a role
                    5. Save, then copy the token (it looks like: loopfollow-1234567890abcdef)
                    """)

                    Text("Which Role Do I Need?")
                        .font(.headline)
                    Text("""
                    • Read — sufficient for most setups, including Loop and Trio remote control via APNS
                    • Read & Write (Careportal) — required only for Nightscout Remote Control (Trio 0.2.x or older)

                    If your Nightscout site is publicly readable, you can leave the token empty. The status will show "OK (Read)".
                    """)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Access Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { activeInfoSheet = nil }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
