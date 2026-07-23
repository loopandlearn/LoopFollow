// LoopFollow
// NightscoutConnectStepView.swift

import SwiftUI

/// The Nightscout connect phase, split into two internal pages:
/// 1. **Address** — enter the site URL; we validate it. A public site (or a URL
///    that already carries a token) is done here. A reachable site that needs a
///    token advances to page 2. An unreachable/invalid address stays put with the
///    error shown in the status pill so the user can correct it.
/// 2. **Token** — paste a token or create a read-only one from the API secret.
struct NightscoutConnectStepView: View {
    @ObservedObject var viewModel: NightscoutSettingsViewModel
    @ObservedObject var onboarding: OnboardingViewModel

    private enum Page { case address, token }
    private enum TokenMode: Hashable { case haveToken, createFromSecret }

    @State private var page: Page = .address
    @State private var mode: TokenMode = .haveToken
    @State private var apiSecret: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusPill(
                color: statusColor,
                message: viewModel.friendlyStatus,
                isLoading: viewModel.statusKind == .checking,
                systemImage: statusIcon
            )
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.25), value: viewModel.statusKind)

            switch page {
            case .address:
                addressForm
            case .token:
                tokenForm
            }

            footer
        }
    }

    // MARK: - Pages

    private var addressForm: some View {
        Form {
            titleSection(
                "Connect to Nightscout",
                "Enter your site address. We'll check it, and only ask for a token if your site needs one."
            )
            urlSection
        }
    }

    private var tokenForm: some View {
        Form {
            if viewModel.isConnected || viewModel.provisionedTokenPending {
                tokenDoneSection
            } else {
                titleSection(
                    "Add a token",
                    "This site needs a token. Paste one, or have LoopFollow create a read-only token from your API secret."
                )
                tokenModeSection

                switch mode {
                case .haveToken:
                    tokenSection
                case .createFromSecret:
                    secretSection
                }
            }
        }
    }

    /// Shown once a token is in place, so the page reads as "done — continue"
    /// rather than still asking the user to do something.
    private var tokenDoneSection: some View {
        Section {
            EmptyView()
        } header: {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.provisionedTokenPending ? "Token created" : "You're connected")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                Text(viewModel.provisionedTokenPending
                    ? "Your read-only token is ready. Tap Continue to keep going — your site may take a few minutes to start accepting it."
                    : "Your read-only token is set up. Tap Continue to keep going.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(nil)
            .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var footer: some View {
        switch page {
        case .address:
            OnboardingNavFooter(
                continueEnabled: viewModel.isConnected || viewModel.addressNeedsToken,
                showBack: onboarding.canGoBack,
                onBack: { onboarding.goBack() },
                onContinue: addressContinue
            )
        case .token:
            OnboardingNavFooter(
                continueEnabled: viewModel.isConnected || viewModel.provisionedTokenPending,
                showBack: true,
                onBack: { withAnimation(.easeInOut(duration: 0.25)) { page = .address } },
                onContinue: { onboarding.advance() }
            )
        }
    }

    private func addressContinue() {
        if viewModel.isConnected {
            onboarding.advance()
        } else if viewModel.addressNeedsToken {
            withAnimation(.easeInOut(duration: 0.25)) { page = .token }
        }
    }

    // MARK: - Sections

    private func titleSection(_ title: String, _ subtitle: String) -> some View {
        Section {
            EmptyView()
        } header: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(nil)
            .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var urlSection: some View {
        Section {
            // `verbatim:` keeps SwiftUI from auto-linking the example URL in accent
            // blue (which reads as an "active" field).
            ZStack(alignment: .leading) {
                if viewModel.nightscoutURL.isEmpty {
                    Text(verbatim: "https://your-site.example.com")
                        .foregroundColor(.secondary)
                }
                TextField("", text: $viewModel.nightscoutURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(.primary)
                    .onChange(of: viewModel.nightscoutURL) { newValue in
                        viewModel.processURL(newValue)
                    }
            }
        } header: {
            Text("Site URL")
        } footer: {
            Text("Enter or paste your full Nightscout address. If the link already includes a token, we'll fill both in for you.")
        }
    }

    private var tokenModeSection: some View {
        Section {
            Picker("Token", selection: $mode) {
                Text("I have a token").tag(TokenMode.haveToken)
                Text("Create one for me").tag(TokenMode.createFromSecret)
            }
            .pickerStyle(.segmented)
        } footer: {
            if mode == .createFromSecret {
                Text("Your API secret is used once to create a read-only access token and is never stored.")
            } else {
                Text("Type or paste a token, or a full Nightscout URL that includes a token.")
            }
        }
    }

    private var tokenSection: some View {
        Section(header: Text("Access Token")) {
            HStack {
                Text("Token")
                TogglableSecureInput(
                    placeholder: "Enter Token",
                    text: $viewModel.nightscoutToken,
                    style: .singleLine,
                    textContentType: .password
                )
            }

            if viewModel.tokenIsVerifiedSecret || viewModel.isProvisioningToken {
                Button {
                    viewModel.createReadOnlyToken(fromSecret: viewModel.nightscoutToken)
                } label: {
                    HStack {
                        if viewModel.isProvisioningToken {
                            ProgressView()
                            Text("Creating read-only token…")
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("That's your API secret — create a read-only token")
                        }
                    }
                }
                .disabled(viewModel.isProvisioningToken)
            }

            if let error = viewModel.tokenProvisionError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    private var secretSection: some View {
        Section(header: Text("API Secret")) {
            HStack {
                Text("Secret")
                TogglableSecureInput(
                    placeholder: "Enter API Secret",
                    text: $apiSecret,
                    style: .singleLine,
                    textContentType: .password
                )
            }

            Button {
                viewModel.createReadOnlyToken(fromSecret: apiSecret)
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isProvisioningToken {
                        ProgressView()
                    } else {
                        Text("Create Read-Only Token")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(viewModel.isProvisioningToken
                || apiSecret.isEmpty
                || viewModel.nightscoutURL.isEmpty)

            if let error = viewModel.tokenProvisionError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Status pill mapping

    private var statusColor: Color {
        switch viewModel.statusKind {
        case .idle: return .secondary
        case .checking: return .orange
        case .pending: return .blue
        case .needsToken, .connected: return .green
        case .error: return .red
        }
    }

    private var statusIcon: String? {
        switch viewModel.statusKind {
        case .idle: return "globe"
        case .checking: return nil
        case .pending: return "clock.badge.checkmark"
        case .needsToken: return "checkmark.circle"
        case .connected: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
