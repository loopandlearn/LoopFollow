// LoopFollow
// LoopRemoteInsulinView.swift
// Created by codebymini

import HealthKit
import LocalAuthentication
import SwiftUI

struct LoopRemoteInsulinView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var insulinAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success

    @FocusState private var insulinFieldIsFocused: Bool

    enum AlertType {
        case success
        case error
        case confirmation
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section {
                        HKQuantityInputView(
                            label: "Insulin Amount",
                            quantity: $insulinAmount,
                            unit: .internationalUnit(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.05),
                            maxValue: HKQuantity(unit: .internationalUnit(), doubleValue: 25.0),
                            isFocused: $insulinFieldIsFocused,
                            onValidationError: { message in
                                alertMessage = message
                                alertType = .error
                                showAlert = true
                            }
                        )
                    }

                    Section(header: Text("Security")) {
                        VStack(alignment: .leading) {
                            Text("Current OTP Code")
                                .font(.headline)
                            if let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopQrCodeURL.value) {
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

                    Section {
                        Button(action: sendInsulin) {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Sending...")
                                }
                            } else {
                                Text("Send Insulin")
                            }
                        }
                        .disabled(insulinAmount.doubleValue(for: .internationalUnit()) <= 0 || isLoading)
                        .frame(maxWidth: .infinity)
                    }
                }
                .navigationTitle("Remote Insulin")
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .success:
                    return Alert(
                        title: Text("Success"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                case .error:
                    return Alert(
                        title: Text("Error"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                case .confirmation:
                    return Alert(
                        title: Text("Confirm Insulin"),
                        message: Text("Send \(String(format: "%.1f", insulinAmount.doubleValue(for: .internationalUnit()))) units of insulin?"),
                        primaryButton: .default(Text("Send")) {
                            authenticateAndSendInsulin()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }

    private func sendInsulin() {
        guard insulinAmount.doubleValue(for: .internationalUnit()) > 0 else {
            alertMessage = "Please enter a valid insulin amount"
            alertType = .error
            showAlert = true
            return
        }

        alertType = .confirmation
        showAlert = true
    }

    private func authenticateAndSendInsulin() {
        let context = LAContext()
        var error: NSError?

        let reason = "Confirm your identity to send insulin."

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        sendInsulinConfirmed()
                    } else {
                        alertMessage = "Authentication failed"
                        alertType = .error
                        showAlert = true
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        sendInsulinConfirmed()
                    } else {
                        alertMessage = "Authentication failed"
                        alertType = .error
                        showAlert = true
                    }
                }
            }
        } else {
            alertMessage = "Biometric authentication not available"
            alertType = .error
            showAlert = true
        }
    }

    private func sendInsulinConfirmed() {
        isLoading = true

        // Extract OTP from QR code URL
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code."
            alertType = .error
            isLoading = false
            showAlert = true
            return
        }

        // Create the remote bolus notification payload using legacy format
        let payload: [String: String] = [
            "eventType": "Remote Bolus Entry",
            "remoteBolus": "\(insulinAmount.doubleValue(for: .internationalUnit()))",
            "otp": otpCode,
        ]

        // Send to Nightscout notifications endpoint
        Task {
            do {
                let nightscoutURL = Storage.shared.url.value
                let apiSecret = Storage.shared.loopApiSecret.value

                let url = URL(string: "\(nightscoutURL)/api/v2/notifications/loop")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiSecret.sha1, forHTTPHeaderField: "api-secret")

                let jsonData = try JSONSerialization.data(withJSONObject: payload)
                request.httpBody = jsonData

                let (data, response) = try await URLSession.shared.data(for: request)

                DispatchQueue.main.async {
                    isLoading = false

                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200
                    {
                        alertMessage = "Insulin sent successfully!"
                        alertType = .success
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let responseText = String(data: data, encoding: .utf8) ?? "No response data"
                        alertMessage = "Failed to send insulin. Status: \(statusCode), Response: \(responseText)"
                        alertType = .error
                    }
                    showAlert = true
                }
            } catch {
                print("[DEBUG] Error: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                    alertMessage = "Error sending insulin: \(error.localizedDescription)"
                    alertType = .error
                    showAlert = true
                }
            }
        }
    }
}
