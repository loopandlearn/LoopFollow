//
//  BolusView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit
import LocalAuthentication

struct BolusView: View {
    @State private var bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    private let pushNotificationManager = PushNotificationManager()
    @ObservedObject private var maxBolus = Storage.shared.maxBolus

    @FocusState private var bolusFieldIsFocused: Bool

    @State private var showAlert = false
    @State private var alertType: AlertType? = nil
    @State private var isLoading = false
    @State private var statusMessage: String? = nil

    enum AlertType {
        case confirmBolus
        case status
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
                            isFocused: $bolusFieldIsFocused
                        )
                    }

                    LoadingButtonView(
                        buttonText: "Send Bolus",
                        progressText: "Sending Bolus...",
                        isLoading: isLoading,
                        action: {
                            bolusFieldIsFocused = false
                            if bolusAmount.doubleValue(for: HKUnit.internationalUnit()) != 0.0 {
                                alertType = .confirmBolus
                                showAlert = true
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
                            authenticateUser { success in
                                if success {
                                    sendBolus()
                                } else {
                                    statusMessage = "Authentication failed. Please try again."
                                    alertType = .status
                                    showAlert = true
                                }
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                case .status:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
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
        bolusFieldIsFocused = false

        pushNotificationManager.sendBolusPushNotification(commandType: "bolus", bolusAmount: bolusAmount) { success in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
                    statusMessage = "Bolus command sent successfully."
                } else {
                    statusMessage = "Failed to send bolus command."
                }
                alertType = .status
                showAlert = true
            }
        }
    }

    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        let reason = "Confirm your identity to send bolus."

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
}
