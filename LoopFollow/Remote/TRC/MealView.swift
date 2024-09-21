//
//  MealView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct MealView: View {
    @State private var carbs = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var protein = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var fat = HKQuantity(unit: .gram(), doubleValue: 0.0)
    private let pushNotificationManager = PushNotificationManager()

    @ObservedObject private var maxCarbs = Storage.shared.maxCarbs
    @ObservedObject private var maxProtein = Storage.shared.maxProtein
    @ObservedObject private var maxFat = Storage.shared.maxFat

    @FocusState private var carbsFieldIsFocused: Bool
    @FocusState private var proteinFieldIsFocused: Bool
    @FocusState private var fatFieldIsFocused: Bool

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var alertMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    enum AlertType {
        case confirmMeal
        case status
        case validationError
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Meal Data")) {
                        HKQuantityInputView(
                            label: "Carbs",
                            quantity: $carbs,
                            unit: .gram(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                            maxValue: maxCarbs.value,
                            isFocused: $carbsFieldIsFocused,
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )

                        HKQuantityInputView(
                            label: "Protein",
                            quantity: $protein,
                            unit: .gram(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                            maxValue: maxProtein.value,
                            isFocused: $proteinFieldIsFocused,
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )

                        HKQuantityInputView(
                            label: "Fat",
                            quantity: $fat,
                            unit: .gram(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                            maxValue: maxFat.value,
                            isFocused: $fatFieldIsFocused,
                            onValidationError: { message in
                                handleValidationError(message)
                            }
                        )
                    }

                    LoadingButtonView(
                        buttonText: "Send Meal",
                        progressText: "Sending Meal Data...",
                        isLoading: isLoading,
                        action: {
                            carbsFieldIsFocused = false
                            proteinFieldIsFocused = false
                            fatFieldIsFocused = false

                            let carbsAmount = carbs.doubleValue(for: HKUnit.gram())
                            let proteinAmount = protein.doubleValue(for: HKUnit.gram())
                            let fatAmount = fat.doubleValue(for: HKUnit.gram())

                            if carbsAmount > 0 || proteinAmount > 0 || fatAmount > 0 {
                                alertType = .confirmMeal
                                showAlert = true
                            }
                        },
                        isDisabled: isButtonDisabled
                    )
                }
                .navigationTitle("Meal")
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmMeal:
                    let carbsAmount = carbs.doubleValue(for: HKUnit.gram())
                    let proteinAmount = protein.doubleValue(for: HKUnit.gram())
                    let fatAmount = fat.doubleValue(for: HKUnit.gram())

                    var message = "Are you sure you want to send the meal data?"

                    if carbsAmount > 0 {
                        message += String(format: "\nCarbs: %.0f g", carbsAmount)
                    }

                    if proteinAmount > 0 {
                        message += String(format: "\nProtein: %.0f g", proteinAmount)
                    }

                    if fatAmount > 0 {
                        message += String(format: "\nFat: %.0f g", fatAmount)
                    }

                    return Alert(
                        title: Text("Confirm Meal"),
                        message: Text(message),
                        primaryButton: .default(Text("Confirm"), action: {
                            sendMealCommand()
                        }),
                        secondaryButton: .cancel()
                    )
                case .status:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            showAlert = false
                        })
                    )
                case .validationError:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            showAlert = false
                        })
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }

    private var isButtonDisabled: Bool {
        return isLoading
    }

    private func sendMealCommand() {
        carbsFieldIsFocused = false
        proteinFieldIsFocused = false
        fatFieldIsFocused = false
        isLoading = true

        pushNotificationManager.sendMealPushNotification(carbs: carbs, protein: protein, fat: fat) { success, errorMessage in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    statusMessage = "Meal command sent successfully."
                } else {
                    statusMessage = errorMessage ?? "Failed to send meal command."
                }
                alertType = .status
                showAlert = true
            }
        }
    }

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validationError
        showAlert = true
    }
}
