// LoopFollow
// RemoteSettingsView.swift
// Created by Jonas Björkert.

import HealthKit
import SwiftUI

struct RemoteSettingsView: View {
    @ObservedObject var viewModel: RemoteSettingsViewModel
    @ObservedObject private var device = Storage.shared.device

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil

    enum AlertType {
        case validation
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Remote Type Section (Custom Rows)

                Section(header: Text("Remote Type")) {
                    remoteTypeRow(type: .none, label: "None", isEnabled: true)

                    remoteTypeRow(type: .nightscout, label: "Nightscout", isEnabled: true)

                    remoteTypeRow(
                        type: .trc,
                        label: "Trio Remote Control",
                        isEnabled: viewModel.isTrioDevice
                    )

                    Text("Nightscout is the only option for Loop.\nNightscout should be used for Trio 0.2.x or older.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                // MARK: - User Information Section

                if viewModel.remoteType != .none {
                    Section(header: Text("User Information")) {
                        HStack {
                            Text("User")
                            TextField("Enter User", text: $viewModel.user)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                // MARK: - Loop Remote Setup Section

                if viewModel.remoteType == .nightscout && device.value == "Loop" {
                    Section(header: Text("Loop Remote Setup")) {
                        VStack(alignment: .leading) {
                            Text("Nightscout URL")
                                .font(.headline)
                            Text(Storage.shared.url.value.isEmpty ? "Not configured" : Storage.shared.url.value)
                                .foregroundColor(Storage.shared.url.value.isEmpty ? .red : .primary)
                                .font(.body)
                        }

                        VStack(alignment: .leading) {
                            Text("API Secret")
                                .font(.headline)
                            TogglableSecureInput(
                                placeholder: "Your Nightscout API secret",
                                text: $viewModel.loopApiSecret,
                                style: .singleLine
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        }

                        if viewModel.loopQrCodeURL.isEmpty {
                            Button(action: {
                                viewModel.isShowingScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                    Text("Scan QR Code")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }

                        VStack(alignment: .leading) {
                            Text("QR Code URL")
                                .font(.headline)
                            TextField("QR Code URL from Loop", text: $viewModel.loopQrCodeURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        if !viewModel.loopQrCodeURL.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Current OTP Code")
                                    .font(.headline)
                                if let otpCode = TOTPGenerator.extractOTPFromURL(viewModel.loopQrCodeURL) {
                                    Text(otpCode)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.green)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                } else {
                                    Text("Invalid QR code URL")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }

                        // Show setup status instead of manual save button
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: viewModel.loopRemoteSetup ? "checkmark.circle.fill" : "exclamationmark.circle")
                                    .foregroundColor(viewModel.loopRemoteSetup ? .green : .orange)
                                Text(viewModel.loopRemoteSetup ? "Setup Complete" : "Setup Incomplete")
                                    .font(.headline)
                                    .foregroundColor(viewModel.loopRemoteSetup ? .green : .orange)
                            }

                            if !viewModel.loopRemoteSetup {
                                Text("Please ensure both API Secret and QR Code are configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // MARK: - Trio Remote Control Settings

                if viewModel.remoteType == .trc {
                    Section(header: Text("Trio Remote Control Settings")) {
                        HStack {
                            Text("Shared Secret")
                            TogglableSecureInput(
                                placeholder: "Enter Shared Secret",
                                text: $viewModel.sharedSecret,
                                style: .singleLine
                            )
                        }

                        HStack {
                            Text("APNS Key ID")
                            TogglableSecureInput(
                                placeholder: "Enter APNS Key ID",
                                text: $viewModel.keyId,
                                style: .singleLine
                            )
                        }

                        VStack(alignment: .leading) {
                            Text("APNS Key")
                            TogglableSecureInput(
                                placeholder: "Paste APNS Key",
                                text: $viewModel.apnsKey,
                                style: .multiLine
                            )
                            .frame(minHeight: 110)
                        }
                    }

                    // MARK: - Meal Section

                    Section(header: Text("Meal Settings")) {
                        Toggle("Meal with Bolus", isOn: $viewModel.mealWithBolus)
                            .toggleStyle(SwitchToggleStyle())

                        Toggle("Meal with Fat/Protein", isOn: $viewModel.mealWithFatProtein)
                            .toggleStyle(SwitchToggleStyle())
                    }

                    // MARK: - Debug / Info

                    Section(header: Text("Debug / Info")) {
                        Text("Device Token: \(Storage.shared.deviceToken.value)")
                        Text("Production Env.: \(Storage.shared.productionEnvironment.value ? "True" : "False")")
                        Text("Team ID: \(Storage.shared.teamId.value ?? "")")
                        Text("Bundle ID: \(Storage.shared.bundleId.value)")
                    }
                }

                // MARK: - Shared Guardrails Section

                if viewModel.remoteType != .none {
                    guardrailsSection
                }
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .validation:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? "Invalid input."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingScanner) {
            SimpleQRCodeScannerView { result in
                viewModel.handleQRCodeScanResult(result)
            }
        }
        .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
        .navigationBarTitle("Remote Settings", displayMode: .inline)
    }

    // MARK: - Custom Row for Remote Type Selection

    private func remoteTypeRow(type: RemoteType, label: String, isEnabled: Bool) -> some View {
        Button(action: {
            if isEnabled {
                viewModel.remoteType = type
            }
        }) {
            HStack {
                Text(label)
                Spacer()
                if viewModel.remoteType == type {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        // If isEnabled is false, user can see the row but not tap it.
        .disabled(!isEnabled)
        .foregroundColor(isEnabled ? .primary : .gray)
    }

    // MARK: - Validation Error Handler

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validation
        showAlert = true
    }

    private var guardrailsSection: some View {
        Section(header: Text("Guardrails")) {
            HStack {
                Text("Max Bolus")
                Spacer()
                TextFieldWithToolBar(
                    quantity: $viewModel.maxBolus,
                    maxLength: 4,
                    unit: HKUnit.internationalUnit(),
                    allowDecimalSeparator: true,
                    minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0),
                    maxValue: HKQuantity(unit: .internationalUnit(), doubleValue: 10),
                    onValidationError: { message in
                        handleValidationError(message)
                    }
                )
                .frame(width: 100)
                Text("U")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Max Carbs")
                Spacer()
                TextFieldWithToolBar(
                    quantity: $viewModel.maxCarbs,
                    maxLength: 4,
                    unit: HKUnit.gram(),
                    allowDecimalSeparator: true,
                    minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                    maxValue: HKQuantity(unit: .gram(), doubleValue: 100),
                    onValidationError: { message in
                        handleValidationError(message)
                    }
                )
                .frame(width: 100)
                Text("g")
                    .foregroundColor(.secondary)
            }

            if device.value == "Trio" {
                HStack {
                    Text("Max Protein")
                    Spacer()
                    TextFieldWithToolBar(
                        quantity: $viewModel.maxProtein,
                        maxLength: 4,
                        unit: HKUnit.gram(),
                        allowDecimalSeparator: true,
                        minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                        maxValue: HKQuantity(unit: .gram(), doubleValue: 100),
                        onValidationError: { message in
                            handleValidationError(message)
                        }
                    )
                    .frame(width: 100)
                    Text("g")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Max Fat")
                    Spacer()
                    TextFieldWithToolBar(
                        quantity: $viewModel.maxFat,
                        maxLength: 4,
                        unit: HKUnit.gram(),
                        allowDecimalSeparator: true,
                        minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                        maxValue: HKQuantity(unit: .gram(), doubleValue: 100),
                        onValidationError: { message in
                            handleValidationError(message)
                        }
                    )
                    .frame(width: 100)
                    Text("g")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
