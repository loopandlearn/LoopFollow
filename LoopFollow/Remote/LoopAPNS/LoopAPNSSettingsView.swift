// LoopFollow
// LoopAPNSSettingsView.swift
// Created by codebymini.

import SwiftUI

struct LoopAPNSSettingsView: View {
    @ObservedObject var viewModel: RemoteSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: viewModel.loopAPNSSetup ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(viewModel.loopAPNSSetup ? .green : .orange)
                            Text(viewModel.loopAPNSSetup ? "Setup Complete" : "Setup Incomplete")
                                .font(.headline)
                                .foregroundColor(viewModel.loopAPNSSetup ? .green : .orange)
                        }

                        if !viewModel.loopAPNSSetup {
                            Text("Configure all required fields below to complete the Loop APNS setup")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("All required fields are configured. You can now use Loop APNS features.")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Setup Status")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOOP APNS KEY ID")
                            .font(.headline)
                        TogglableSecureInput(
                            placeholder: "Enter your APNS Key ID",
                            text: $viewModel.keyId,
                            style: .singleLine
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOOP DEVELOPER TEAM ID")
                            .font(.headline)
                        TogglableSecureInput(
                            placeholder: "Enter your Team ID (10 characters)",
                            text: $viewModel.loopDeveloperTeamId,
                            style: .singleLine
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("LOOP APNS KEY")
                            .font(.headline)
                        TogglableSecureInput(
                            placeholder: "Enter your APNS Key including -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----",
                            text: $viewModel.apnsKey,
                            style: .multiLine
                        )
                        .frame(minHeight: 110)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("QR Code URL")
                            .font(.headline)
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Environment")
                            .font(.headline)
                        Toggle("Production Environment", isOn: $viewModel.productionEnvironment)
                            .toggleStyle(SwitchToggleStyle())
                        Text("Production is used for browser builders and should be switched off for Xcode builders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                } header: {
                    Text("Loop APNS Configuration")
                }

                if let errorMessage = viewModel.loopAPNSErrorMessage, !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationBarTitle("Loop APNS Settings", displayMode: .inline)
            .sheet(isPresented: $viewModel.isShowingLoopAPNSScanner) {
                SimpleQRCodeScannerView { result in
                    viewModel.handleLoopAPNSQRCodeScanResult(result)
                }
            }
        }
    }
}

// MARK: - RemoteSettingsViewModel Extension for Loop APNS

extension RemoteSettingsViewModel {}
