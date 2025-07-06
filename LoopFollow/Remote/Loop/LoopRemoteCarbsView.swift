// LoopFollow
// LoopRemoteCarbsView.swift
// Created by codebymini

import HealthKit
import SwiftUI

struct LoopRemoteCarbsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var carbsAmount = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var absorptionTime = HKQuantity(unit: .hour(), doubleValue: 3.0)
    @State private var foodType = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success

    @FocusState private var carbsFieldIsFocused: Bool
    @FocusState private var absorptionFieldIsFocused: Bool

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
                            label: "Carbs Amount",
                            quantity: $carbsAmount,
                            unit: .gram(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 1.0),
                            maxValue: HKQuantity(unit: .gram(), doubleValue: 200.0),
                            isFocused: $carbsFieldIsFocused,
                            onValidationError: { message in
                                alertMessage = message
                                alertType = .error
                                showAlert = true
                            }
                        )

                        HKQuantityInputView(
                            label: "Absorption Time",
                            quantity: $absorptionTime,
                            unit: .hour(),
                            maxLength: 3,
                            minValue: HKQuantity(unit: .hour(), doubleValue: 1.0),
                            maxValue: HKQuantity(unit: .hour(), doubleValue: 8.0),
                            isFocused: $absorptionFieldIsFocused,
                            onValidationError: { message in
                                alertMessage = message
                                alertType = .error
                                showAlert = true
                            }
                        )

                        VStack(alignment: .leading) {
                            Text("Food Type (optional)")
                                .font(.headline)
                            TextField("e.g., Breakfast, Lunch, Snack", text: $foodType)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
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
                        Button(action: sendCarbs) {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Sending...")
                                }
                            } else {
                                Text("Send Carbs")
                            }
                        }
                        .disabled(carbsAmount.doubleValue(for: .gram()) <= 0 || isLoading)
                        .frame(maxWidth: .infinity)
                    }
                }
                .navigationTitle("Remote Carbs")
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
                        title: Text("Confirm Carbs"),
                        message: Text("Send \(Int(carbsAmount.doubleValue(for: .gram())))g of carbs with \(Int(absorptionTime.doubleValue(for: .hour())))h absorption time?"),
                        primaryButton: .default(Text("Send")) {
                            sendCarbsConfirmed()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }

    private func sendCarbs() {
        guard carbsAmount.doubleValue(for: .gram()) > 0 else {
            alertMessage = "Please enter a valid carb amount"
            alertType = .error
            showAlert = true
            return
        }

        alertType = .confirmation
        showAlert = true
    }

    private func sendCarbsConfirmed() {
        isLoading = true

        // Extract OTP from QR code URL
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code."
            alertType = .error
            isLoading = false
            showAlert = true
            return
        }

        // Create the remote carbs notification payload using legacy format
        var payload: [String: String] = [
            "eventType": "Remote Carbs Entry",
            "remoteCarbs": "\(carbsAmount.doubleValue(for: .gram()))",
            "remoteAbsorption": "\(absorptionTime.doubleValue(for: .hour()))",
            "otp": otpCode,
        ]

        // Add food type if provided
        if !foodType.isEmpty {
            payload["foodType"] = foodType
        }

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
                        alertMessage = "Carbs sent successfully!"
                        alertType = .success
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let responseText = String(data: data, encoding: .utf8) ?? "No response data"
                        alertMessage = "Failed to send carbs. Status: \(statusCode), Response: \(responseText)"
                        alertType = .error
                    }
                    showAlert = true
                }
            } catch {
                print("[DEBUG] Error: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                    alertMessage = "Error sending carbs: \(error.localizedDescription)"
                    alertType = .error
                    showAlert = true
                }
            }
        }
    }
}
