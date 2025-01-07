//
//  RemoteSettingsView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Updated on 2024-09-16.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct RemoteSettingsView: View {
    @ObservedObject var viewModel: RemoteSettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var focusedField: Field?

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil

    enum Field: Hashable {
        case user
        case deviceToken
        case sharedSecret
        case apnsKey
        case teamId
        case keyId
        case bundleId
        case maxBolus
    }

    enum AlertType {
        case validation
    }

    var body: some View {
        NavigationView {
            Form {
                // Remote Type Section
                // Instructions for Remote Type options
                Section {
                    Picker("Remote Type", selection: $viewModel.remoteType) {
                        Text("None").tag(RemoteType.none)
                        Text("Nightscout").tag(RemoteType.nightscout)
                        if BuildDetails.default.branch?.lowercased() != "main" {
                            Text("Trio Remote Control").tag(RemoteType.trc)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Text("Nightscout is the only option available for the released version of Trio.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Trio Remote Control requires a special version of Trio, which is under development in a private repository until sufficient testing is completed.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                // User Information Section
                if viewModel.remoteType != .none {
                    Section(header: Text("User Information")) {
                        HStack {
                            Text("User")
                            TextField("Enter User", text: $viewModel.user)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .user)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                // Trio Remote Control Settings Section
                if viewModel.remoteType == .trc {
                    Section(header: Text("Trio Remote Control Settings")) {
                        HStack {
                            Text("Shared Secret")
                            TextField("Enter Shared Secret", text: $viewModel.sharedSecret)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .sharedSecret)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("APNS Key ID")
                            TextField("Enter APNS Key ID", text: $viewModel.keyId)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .keyId)
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
                                .focused($focusedField, equals: .apnsKey)
                        }

                    }

                    // Guardrails Section
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

                    // Meal Section
                    Section(header: Text("Meal Settings")) {
                        Toggle("Meal with Bolus", isOn: $viewModel.mealWithBolus)
                            .toggleStyle(SwitchToggleStyle())

                        Toggle("Meal with Fat/Protein", isOn: $viewModel.mealWithFatProtein)
                            .toggleStyle(SwitchToggleStyle())
                    }

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
            .onTapGesture {
                focusedField = nil
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

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validation
        showAlert = true
    }
}
