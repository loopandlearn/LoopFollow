// LoopFollow
// RemoteSettingsView.swift
// Created by Jonas Björkert on 2024-09-17.

import HealthKit
import SwiftUI

struct RemoteSettingsView: View {
    @ObservedObject var viewModel: RemoteSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

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

                    if BuildDetails.default.branch?.lowercased() != "main" {
                        remoteTypeRow(
                            type: .trc,
                            label: "Trio Remote Control",
                            isEnabled: viewModel.isTrioDevice
                        )
                    }

                    Text("Nightscout is the only option for the released version of Trio and Loop.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    if BuildDetails.default.branch?.lowercased() != "main" {
                        Text("Trio Remote Control requires a special version of Trio, which is under development in a private repository until sufficient testing is completed.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
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

                // MARK: - Trio Remote Control Settings

                if viewModel.remoteType == .trc {
                    Section(header: Text("Trio Remote Control Settings")) {
                        HStack {
                            Text("Shared Secret")
                            TextField("Enter Shared Secret", text: $viewModel.sharedSecret)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("APNS Key ID")
                            TextField("Enter APNS Key ID", text: $viewModel.keyId)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .multilineTextAlignment(.trailing)
                        }

                        VStack(alignment: .leading) {
                            Text("APNS Key")
                            TextEditor(text: $viewModel.apnsKey)
                                .frame(height: 100)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }

                    // MARK: - Guardrails

                    Section(header: Text("Guardrails")) {
                        HStack {
                            Text("Max Bolus")
                            Spacer()
                            TextFieldWithToolBar(
                                quantity: $viewModel.maxBolus,
                                maxLength: 4,
                                unit: HKUnit.internationalUnit(),
                                allowDecimalSeparator: true,
                                minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.0),
                                maxValue: HKQuantity(unit: .internationalUnit(), doubleValue: 10.0),
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
            }
            .navigationBarTitle("Remote Settings", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
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
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
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
}
