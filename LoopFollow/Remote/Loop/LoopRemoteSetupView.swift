// LoopFollow
// LoopRemoteSetupView.swift
// Created by codebymini

import SwiftUI

struct LoopRemoteSetupView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var nightscoutURL: String = Storage.shared.url.value
    @State private var apiSecret: String = Storage.shared.loopApiSecret.value
    @State private var qrCodeURL: String = ""
    @State private var isShowingScanner = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Loop Remote Setup")) {
                    VStack(alignment: .leading) {
                        Text("Nightscout URL")
                            .font(.headline)
                        Text(nightscoutURL.isEmpty ? "Not configured" : nightscoutURL)
                            .foregroundColor(nightscoutURL.isEmpty ? .red : .primary)
                            .font(.body)
                    }

                    VStack(alignment: .leading) {
                        Text("API Secret")
                            .font(.headline)
                        SecureField("Your Nightscout API secret", text: $apiSecret)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    if qrCodeURL.isEmpty {
                        Button(action: {
                            isShowingScanner = true
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
                        TextField("QR Code URL from Loop", text: $qrCodeURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    if !qrCodeURL.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Current OTP Code")
                                .font(.headline)
                            if let otpCode = TOTPGenerator.extractOTPFromURL(qrCodeURL) {
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
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: saveRemoteSetup) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                            }
                        } else {
                            Text("Save Remote Setup")
                        }
                    }
                    .disabled(apiSecret.isEmpty || qrCodeURL.isEmpty || isLoading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Loop Remote Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $isShowingScanner) {
            SimpleQRCodeScannerView { result in
                switch result {
                case let .success(code):
                    qrCodeURL = code
                case let .failure(error):
                    errorMessage = "Scanning failed: \(error.localizedDescription)"
                }
                isShowingScanner = false
            }
        }
    }

    private func saveRemoteSetup() {
        isLoading = true

        // Validate the setup
        guard !nightscoutURL.isEmpty else {
            errorMessage = "Please configure your Nightscout URL in the main settings"
            isLoading = false
            return
        }

        guard !apiSecret.isEmpty else {
            errorMessage = "Please configure your API Secret in the main settings"
            isLoading = false
            return
        }

        guard !qrCodeURL.isEmpty else {
            errorMessage = "Please scan the QR code from your Loop app"
            isLoading = false
            return
        }

        // Save QR code URL and API Secret to storage and mark setup as complete
        Storage.shared.loopQrCodeURL.value = qrCodeURL
        Storage.shared.loopApiSecret.value = apiSecret
        Storage.shared.loopRemoteSetup.value = true

        isLoading = false
        presentationMode.wrappedValue.dismiss()
    }
}
