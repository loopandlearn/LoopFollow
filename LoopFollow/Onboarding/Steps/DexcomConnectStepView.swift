// LoopFollow
// DexcomConnectStepView.swift

import SwiftUI

struct DexcomConnectStepView: View {
    @ObservedObject var viewModel: DexcomSettingsViewModel
    @ObservedObject var onboarding: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusPill(
                color: statusColor,
                message: viewModel.statusMessage,
                isLoading: viewModel.statusKind == .checking,
                systemImage: statusIcon
            )
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.25), value: viewModel.statusKind)

            form
            OnboardingNavFooter(
                continueEnabled: viewModel.canVerifyProceed,
                showBack: onboarding.canGoBack,
                onBack: { onboarding.goBack() },
                onContinue: { onboarding.advance() }
            )
        }
    }

    private var form: some View {
        Form {
            Section {
                EmptyView()
            } header: {
                OnboardingStepHeader(
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    title: "Connect Dexcom Share",
                    subtitle: "Sign in with the Dexcom Share account that shares glucose data."
                )
                .textCase(nil)
                .padding(.bottom, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section(header: Text("Dexcom Share")) {
                HStack {
                    Text("Username")
                    TextField("Enter Username", text: $viewModel.userName)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Password")
                    TogglableSecureInput(
                        placeholder: "Enter Password",
                        text: $viewModel.password,
                        style: .singleLine,
                        textContentType: .password
                    )
                }

                Picker("Server", selection: $viewModel.server) {
                    Text("US").tag("US")
                    Text("Outside US").tag("NON-US")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Status pill mapping

    private var statusColor: Color {
        switch viewModel.statusKind {
        case .idle: return .secondary
        case .checking: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    private var statusIcon: String? {
        switch viewModel.statusKind {
        case .idle: return "circle"
        case .checking: return nil
        case .connected: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
