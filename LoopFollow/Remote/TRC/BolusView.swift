// LoopFollow
// BolusView.swift

import HealthKit
import LocalAuthentication
import SwiftUI

struct BolusView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    private let pushNotificationManager = PushNotificationManager()
    @ObservedObject private var maxBolus = Storage.shared.maxBolus

    @FocusState private var bolusFieldIsFocused: Bool

    @State private var showAlert = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @State private var isLoading = false
    @State private var statusMessage: String? = nil

    enum AlertType {
        case confirmBolus
        case statusSuccess
        case statusFailure
        case validation
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section {
                        HKQuantityInputView(
                            label: "Bolus Amount",
                            quantity: $bolusAmount,
                            unit: .internationalUnit(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.05),
                            maxValue: maxBolus.value,
                            isFocused: $bolusFieldIsFocused,
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )
                    }

                    LoadingButtonView(
                        buttonText: "Send Bolus",
                        progressText: "Sending Bolus...",
                        isLoading: isLoading,
                        action: {
                            bolusFieldIsFocused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if bolusAmount.doubleValue(for: HKUnit.internationalUnit()) > 0.0 {
                                    alertType = .confirmBolus
                                    showAlert = true
                                }
                            }
                        },
                        isDisabled: isLoading
                    )
                }
                .navigationTitle("Bolus")
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmBolus:
                    return Alert(
                        title: Text("Confirm Bolus"),
                        message: Text("Are you sure you want to send \(bolusAmount.doubleValue(for: HKUnit.internationalUnit()), specifier: "%.2f") U?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            AuthService.authenticate(reason: "Confirm your identity to send bolus.") { result in
                                if case .success = result {
                                    sendBolus()
                                }
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .statusSuccess:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"))
                    )
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

    private func sendBolus() {
        isLoading = true

        pushNotificationManager.sendBolusPushNotification(bolusAmount: bolusAmount) { success, errorMessage in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    statusMessage = "Bolus command sent successfully."
                    LogManager.shared.log(category: .apns, message: "sendBolusPushNotification succeeded - Bolus: \(bolusAmount.doubleValue(for: .internationalUnit())) U")
                    bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
                    alertType = .statusSuccess
                } else {
                    statusMessage = errorMessage ?? "Failed to send bolus command."
                    LogManager.shared.log(category: .apns, message: "sendBolusPushNotification failed with error: \(errorMessage ?? "unknown error")")
                    alertType = .statusFailure
                }
                showAlert = true
            }
        }
    }

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validation
        showAlert = true
    }
}
