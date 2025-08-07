// LoopFollow
// LoopAPNSBolusView.swift
// Created by codebymini.

import HealthKit
import LocalAuthentication
import SwiftUI

struct LoopAPNSBolusView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var insulinAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success

    @FocusState private var insulinFieldIsFocused: Bool

    // Add state for recommended bolus and warning
    @State private var recommendedBolus: Double? = nil
    @State private var lastLoopTime: TimeInterval? = nil
    @State private var otpTimeRemaining: Int? = nil
    @State private var showOldCalculationWarning = false
    private let otpPeriod: TimeInterval = 30
    private var otpTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum AlertType {
        case success
        case error
        case confirmation
        case oldCalculationWarning
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    // Recommended bolus section
                    if let recommendedBolus = recommendedBolus, recommendedBolus > 0, let lastLoopTime = lastLoopTime {
                        let timeSinceCalculation = Date().timeIntervalSince1970 - lastLoopTime
                        let minutesSinceCalculation = Int(timeSinceCalculation / 60)

                        // Only show if calculation is less than 12 minutes old
                        if minutesSinceCalculation < 12 {
                            Section(header: Text("Recommended Bolus")) {
                                Button(action: {
                                    handleRecommendedBolusTap()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(String(format: "%.2f", recommendedBolus))U")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("Calculated \(minutesSinceCalculation) minute\(minutesSinceCalculation == 1 ? "" : "s") ago")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    Section {
                        HKQuantityInputView(
                            label: "Insulin Amount",
                            quantity: $insulinAmount,
                            unit: .internationalUnit(),
                            maxLength: 5,
                            minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.025),
                            maxValue: Storage.shared.maxBolus.value,
                            isFocused: $insulinFieldIsFocused,
                            onValidationError: { message in
                                alertMessage = message
                                alertType = .error
                                showAlert = true
                            }
                        )
                    }

                    // Warning section for recommended bolus age
                    if let recommendedBolus = recommendedBolus, let lastLoopTime = lastLoopTime {
                        let timeSinceCalculation = Date().timeIntervalSince1970 - lastLoopTime
                        let minutesSinceCalculation = Int(timeSinceCalculation / 60)

                        // Only show warning if calculation is less than 12 minutes old
                        if minutesSinceCalculation < 12 {
                            Section {
                                let warningColor: Color = minutesSinceCalculation >= 5 ? .red : .yellow

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("WARNING: New treatments may have occurred since the last recommended bolus was calculated \(presentableMinutesFormat(timeInterval: timeSinceCalculation)) ago.")
                                        .font(.callout)
                                        .foregroundColor(warningColor)
                                        .multilineTextAlignment(.leading)
                                }
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
                .navigationTitle("Insulin")
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

                loadRecommendedBolus()
                // Reset timer state so it shows '-' until first tick
                otpTimeRemaining = nil
            }
            .onReceive(otpTimer) { _ in
                let now = Date().timeIntervalSince1970
                otpTimeRemaining = Int(otpPeriod - (now.truncatingRemainder(dividingBy: otpPeriod)))

                // Check if recommended bolus calculation is older than 5 minutes (but less than 12 minutes)
                if let lastLoopTime = lastLoopTime {
                    let timeSinceCalculation = now - lastLoopTime
                    let minutesSinceCalculation = Int(timeSinceCalculation / 60)

                    // Only show warning if calculation is between 5-12 minutes old
                    if minutesSinceCalculation > 5 && minutesSinceCalculation < 12 && !showOldCalculationWarning {
                        showOldCalculationWarning = true
                        alertMessage = "This recommended bolus was calculated \(minutesSinceCalculation) minutes ago. New treatments may have occurred since then. Proceed with caution."
                        alertType = .oldCalculationWarning
                        showAlert = true
                    }
                }
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
                        title: Text("Confirm Insulin"),
                        message: Text("Send \(String(format: "%.2f", insulinAmount.doubleValue(for: .internationalUnit()))) units of insulin?"),
                        primaryButton: .default(Text("Send")) {
                            authenticateAndSendInsulin()
                        },
                        secondaryButton: .cancel()
                    )
                case .oldCalculationWarning:
                    return Alert(
                        title: Text("Old Calculation Warning"),
                        message: Text(alertMessage),
                        primaryButton: .default(Text("Use Anyway")) {
                            applyRecommendedBolus()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }

    private func loadRecommendedBolus() {
        // Load recommended bolus from Observable
        recommendedBolus = Observable.shared.deviceRecBolus.value
        lastLoopTime = Observable.shared.alertLastLoopTime.value

        // Reset warning state when new data is loaded
        showOldCalculationWarning = false
    }

    private func handleRecommendedBolusTap() {
        guard let recommendedBolus = recommendedBolus, recommendedBolus > 0 else { return }

        // Apply the recommended bolus directly (warning is handled by timer)
        applyRecommendedBolus()
    }

    private func applyRecommendedBolus() {
        guard let recommendedBolus = recommendedBolus, recommendedBolus > 0 else { return }
        insulinAmount = HKQuantity(unit: .internationalUnit(), doubleValue: recommendedBolus)
    }

    private func presentableMinutesFormat(timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        var result = "\(minutes) minute"
        if minutes == 0 || minutes > 1 {
            result += "s"
        }
        return result
    }

    private func sendInsulin() {
        guard insulinAmount.doubleValue(for: .internationalUnit()) > 0 else {
            alertMessage = "Please enter a valid insulin amount"
            alertType = .error
            showAlert = true
            return
        }

        // Check guardrails
        let maxBolus = Storage.shared.maxBolus.value.doubleValue(for: .internationalUnit())
        let insulinValue = insulinAmount.doubleValue(for: .internationalUnit())

        if insulinValue > maxBolus {
            alertMessage = "Insulin amount (\(String(format: "%.2f", insulinValue))U) exceeds the maximum allowed (\(String(format: "%.2f", maxBolus))U). Please reduce the amount."
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
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            isLoading = false
            showAlert = true
            return
        }

        let payload = LoopAPNSPayload(
            type: .bolus,
            bolusAmount: insulinAmount.doubleValue(for: .internationalUnit()),
            otp: otpCode
        )

        Task {
            do {
                let apnsService = LoopAPNSService()
                let success = try await apnsService.sendBolusViaAPNS(payload: payload)

                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        alertMessage = "Insulin sent successfully!"
                        alertType = .success
                        LogManager.shared.log(
                            category: .apns,
                            message: "Insulin sent - Amount: \(insulinAmount.doubleValue(for: .internationalUnit()))U"
                        )
                    } else {
                        alertMessage = "Failed to send insulin. Check your Loop APNS configuration."
                        alertType = .error
                        LogManager.shared.log(
                            category: .apns,
                            message: "Failed to send insulin"
                        )
                    }
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    alertMessage = "Error sending insulin: \(error.localizedDescription)"
                    alertType = .error
                    LogManager.shared.log(
                        category: .apns,
                        message: "APNS insulin error: \(error.localizedDescription)"
                    )
                    showAlert = true
                }
            }
        }
    }
}
