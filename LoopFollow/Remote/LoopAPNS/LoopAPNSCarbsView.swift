// LoopFollow
// LoopAPNSCarbsView.swift
// Created by codebymini.

import HealthKit
import SwiftUI

struct LoopAPNSCarbsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var carbsAmount = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var absorptionTime = HKQuantity(unit: .hour(), doubleValue: 3.0)
    @State private var foodType = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var otpTimeRemaining: Int? = nil
    private let otpPeriod: TimeInterval = 30
    private var otpTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                            maxValue: Storage.shared.maxCarbs.value,
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

                    Section(header: Text("Security")) {
                        VStack(alignment: .leading) {
                            Text("Current OTP Code")
                                .font(.headline)
                            if let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value) {
                                HStack {
                                    Text(otpCode)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.green)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("(" + (otpTimeRemaining.map { "\($0)s left" } ?? "-") + ")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Invalid QR code URL")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .navigationTitle("Carbs")
                .navigationBarTitleDisplayMode(.inline)
            }

            .onAppear {
                // Validate APNS setup
                let apnsService = LoopAPNSService()
                if !apnsService.validateSetup() {
                    alertMessage = "Loop APNS setup is incomplete. Please configure all required fields in settings."
                    alertType = .error
                    showAlert = true
                }
                // Reset timer state so it shows '-' until first tick
                otpTimeRemaining = nil
            }
            .onReceive(otpTimer) { _ in
                let now = Date().timeIntervalSince1970
                otpTimeRemaining = Int(otpPeriod - (now.truncatingRemainder(dividingBy: otpPeriod)))
            }
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

        // Check guardrails
        let maxCarbs = Storage.shared.maxCarbs.value.doubleValue(for: .gram())
        let carbsValue = carbsAmount.doubleValue(for: .gram())

        if carbsValue > maxCarbs {
            alertMessage = "Carbs amount (\(Int(carbsValue))g) exceeds the maximum allowed (\(Int(maxCarbs))g). Please reduce the amount."
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
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            isLoading = false
            showAlert = true
            return
        }

        // Create the APNS payload for carbs
        let payload = LoopAPNSPayload(
            type: .carbs,
            carbsAmount: carbsAmount.doubleValue(for: .gram()),
            absorptionTime: absorptionTime.doubleValue(for: .hour()),
            foodType: foodType.isEmpty ? nil : foodType,
            otp: otpCode
        )

        Task {
            do {
                let apnsService = LoopAPNSService()
                let success = try await apnsService.sendCarbsViaAPNS(payload: payload)

                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        alertMessage = "Carbs sent successfully!"
                        alertType = .success
                        LogManager.shared.log(
                            category: .apns,
                            message: "Carbs sent - Amount: \(carbsAmount.doubleValue(for: .gram()))g, Absorption: \(absorptionTime.doubleValue(for: .hour()))h"
                        )
                    } else {
                        alertMessage = "Failed to send carbs. Check your Loop APNS configuration."
                        alertType = .error
                        LogManager.shared.log(
                            category: .apns,
                            message: "Failed to send carbs"
                        )
                    }
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    alertMessage = "Error sending carbs: \(error.localizedDescription)"
                    alertType = .error
                    LogManager.shared.log(
                        category: .apns,
                        message: "APNS carbs error: \(error.localizedDescription)"
                    )
                    showAlert = true
                }
            }
        }
    }
}

// APNS Payload structure for carbs
struct LoopAPNSPayload {
    enum PayloadType {
        case carbs
        case bolus
    }

    let type: PayloadType
    let carbsAmount: Double?
    let absorptionTime: Double?
    let foodType: String?
    let bolusAmount: Double?
    let otp: String

    init(type: PayloadType, carbsAmount: Double? = nil, absorptionTime: Double? = nil, foodType: String? = nil, bolusAmount: Double? = nil, otp: String) {
        self.type = type
        self.carbsAmount = carbsAmount
        self.absorptionTime = absorptionTime
        self.foodType = foodType
        self.bolusAmount = bolusAmount
        self.otp = otp
    }
}
