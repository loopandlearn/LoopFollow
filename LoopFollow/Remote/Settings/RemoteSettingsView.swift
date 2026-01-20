// LoopFollow
// RemoteSettingsView.swift

import AVFoundation
import HealthKit
import SwiftUI
import UIKit

struct RemoteSettingsView: View {
    @ObservedObject var viewModel: RemoteSettingsViewModel
    @ObservedObject private var device = Storage.shared.device
    @ObservedObject var bolusIncrement = Storage.shared.bolusIncrement

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil

    @State private var otpTimeRemaining: Int? = nil
    private let otpPeriod: TimeInterval = 30
    private var otpTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum AlertType {
        case validation
        case urlTokenValidation
        case urlTokenUpdate
    }

    init(viewModel: RemoteSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            // MARK: - Remote Type Section (Custom Rows)

            Section {
                remoteTypeRow(
                    type: .none,
                    label: "None",
                    isEnabled: true
                )

                remoteTypeRow(
                    type: .loopAPNS,
                    label: "Loop Remote Control",
                    isEnabled: viewModel.isLoopDevice
                )

                remoteTypeRow(
                    type: .trc,
                    label: "Trio Remote Control",
                    isEnabled: viewModel.isTrioDevice
                )

                remoteTypeRow(
                    type: .nightscout,
                    label: "Nightscout",
                    isEnabled: viewModel.isTrioDevice
                )

                Text("Nightscout should be used for Trio 0.2.x.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // MARK: - Import/Export Settings Section

            Section {
                NavigationLink(destination: ImportExportSettingsView()) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                        Text("Import/Export Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }

            // MARK: - Meal Section (for TRC only)

            if viewModel.remoteType == .trc {
                Section(header: Text("Meal Settings")) {
                    Toggle("Meal with Bolus", isOn: $viewModel.mealWithBolus)
                        .toggleStyle(SwitchToggleStyle())

                    Toggle("Meal with Fat/Protein", isOn: $viewModel.mealWithFatProtein)
                        .toggleStyle(SwitchToggleStyle())
                }
            }

            // MARK: - Guardrails Section (shown for both TRC and Loop)

            if viewModel.remoteType == .trc || viewModel.remoteType == .loopAPNS {
                guardrailsSection
            }

            if !Storage.shared.bolusIncrementDetected.value {
                Section(header: Text("Bolus Increment")) {
                    HStack {
                        Text("Increment")
                        Spacer()
                        TextFieldWithToolBar(
                            quantity: $bolusIncrement.value,
                            maxLength: 5,
                            unit: HKUnit.internationalUnit(),
                            allowDecimalSeparator: true,
                            minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.001),
                            maxValue: HKQuantity(unit: .internationalUnit(), doubleValue: 1),
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )
                        .frame(width: 100)
                        Text("U")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - User Information Section

            if viewModel.remoteType != .none && viewModel.remoteType != .loopAPNS {
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

                // MARK: - Debug / Info

                Section(header: Text("Debug / Info")) {
                    Text("Device Token: \(Storage.shared.deviceToken.value)")
                    Text("APNS Environment: \(Storage.shared.productionEnvironment.value ? "Production" : "Development")")
                    Text("Team ID: \(Storage.shared.teamId.value ?? "")")
                    Text("Bundle ID: \(Storage.shared.bundleId.value)")
                    if Storage.shared.bolusIncrementDetected.value {
                        Text("Bolus Increment: \(Storage.shared.bolusIncrement.value.doubleValue(for: .internationalUnit()), specifier: "%.3f") U")
                    }
                }
            }

            // MARK: - Loop APNS Settings

            if viewModel.remoteType == .loopAPNS {
                Section(header: Text("Loop APNS Configuration")) {
                    HStack {
                        Text("Developer Team ID")
                        TogglableSecureInput(
                            placeholder: "Enter Team ID",
                            text: $viewModel.loopDeveloperTeamId,
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

                    HStack {
                        Text("QR Code URL")
                        TextField("Enter QR code URL or scan from Loop app", text: $viewModel.loopAPNSQrCodeURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Button(action: {
                        viewModel.isShowingLoopAPNSScanner = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code from Loop App")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                    HStack {
                        Text("Environment")
                        Spacer()
                        Toggle("Production", isOn: $viewModel.productionEnvironment)
                            .toggleStyle(SwitchToggleStyle())
                    }

                    Text("Production is used for browser builders and should be switched off for Xcode builders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let errorMessage = viewModel.loopAPNSErrorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section(header: Text("Debug / Info")) {
                    Text("Device Token: \(Storage.shared.deviceToken.value)")
                    Text("Bundle ID: \(Storage.shared.bundleId.value)")

                    if let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value) {
                        HStack {
                            Text("Current TOTP Code:")
                            Text(otpCode)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                            Text("(" + (otpTimeRemaining.map { "\($0)s left" } ?? "-") + ")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("TOTP Code: Invalid QR code URL")
                            .foregroundColor(.red)
                    }
                    if Storage.shared.bolusIncrementDetected.value {
                        Text("Bolus Increment: \(Storage.shared.bolusIncrement.value.doubleValue(for: .internationalUnit()), specifier: "%.3f") U")
                    }
                }

                if viewModel.areTeamIdsDifferent {
                    Section(header: Text("Return Notification Settings"), footer: Text("Because LoopFollow and the target app were built with different Team IDs, you must provide the APNS credentials for LoopFollow below.").font(.caption)) {
                        HStack {
                            Text("Return APNS Key ID")
                            TogglableSecureInput(
                                placeholder: "Enter Key ID for LoopFollow",
                                text: $viewModel.returnKeyId,
                                style: .singleLine
                            )
                        }

                        VStack(alignment: .leading) {
                            Text("Return APNS Key")
                            TogglableSecureInput(
                                placeholder: "Paste APNS Key for LoopFollow",
                                text: $viewModel.returnApnsKey,
                                style: .multiLine
                            )
                            .frame(minHeight: 110)
                        }
                    }
                }
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
            case .urlTokenValidation:
                return Alert(
                    title: Text("URL/Token Validation"),
                    message: Text(viewModel.validationMessage),
                    dismissButton: .default(Text("OK")) {
                        viewModel.showURLTokenValidation = false
                    }
                )
            case .urlTokenUpdate:
                return Alert(
                    title: Text("URL/Token Update"),
                    message: Text(viewModel.validationMessage),
                    dismissButton: .default(Text("OK")) {
                        viewModel.showURLTokenValidation = false
                    }
                )
            case .none:
                return Alert(title: Text("Unknown Alert"))
            }
        }
        .sheet(isPresented: $viewModel.isShowingLoopAPNSScanner) {
            SimpleQRCodeScannerView { result in
                viewModel.handleLoopAPNSQRCodeScanResult(result)
            }
        }
        .sheet(isPresented: $viewModel.showURLTokenValidation) {
            NavigationView {
                URLTokenValidationView(
                    settings: viewModel.pendingSettings!,
                    shouldPromptForURL: viewModel.shouldPromptForURL,
                    shouldPromptForToken: viewModel.shouldPromptForToken,
                    message: viewModel.validationMessage,
                    onConfirm: { confirmedSettings in
                        confirmedSettings.applyToStorage()
                        viewModel.updateViewModelFromStorage()
                        viewModel.showURLTokenValidation = false
                        viewModel.pendingSettings = nil
                        LogManager.shared.log(category: .remote, message: "Remote command settings imported from QR code with URL/token updates")
                    },
                    onCancel: {
                        viewModel.showURLTokenValidation = false
                        viewModel.pendingSettings = nil
                    }
                )
            }
        }
        .onAppear {
            // Reset timer state so it shows '-' until first tick
            otpTimeRemaining = nil
            // Update view model from storage to ensure UI is current
            viewModel.updateViewModelFromStorage()
        }
        .onReceive(otpTimer) { _ in
            let now = Date().timeIntervalSince1970
            otpTimeRemaining = Int(otpPeriod - (now.truncatingRemainder(dividingBy: otpPeriod)))
        }
        .onReceive(viewModel.$showURLTokenValidation) { showValidation in
            if showValidation {
                // The sheet will be shown automatically due to the binding
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("Remote Settings")
        .navigationBarTitleDisplayMode(.inline)
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
                    maxLength: 5,
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
