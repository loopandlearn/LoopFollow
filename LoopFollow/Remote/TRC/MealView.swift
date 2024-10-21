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
    @Environment(\.presentationMode) private var presentationMode
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
    @State private var selectedTime: Date = Date()

    enum AlertType {
        case confirmMeal
        case statusSuccess
        case statusFailure
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

                    Section(header: Text("Schedule")) {
                        DatePicker(
                            "Select Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(CompactDatePickerStyle())
                    }

                    LoadingButtonView(
                        buttonText: "Send Meal",
                        progressText: "Sending Meal Data...",
                        isLoading: isLoading,
                        action: {
                            carbsFieldIsFocused = false
                            proteinFieldIsFocused = false
                            fatFieldIsFocused = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                guard carbs.doubleValue(for: .gram()) != 0 ||
                                        protein.doubleValue(for: .gram()) != 0 ||
                                        fat.doubleValue(for: .gram()) != 0 else {
                                    return
                                }

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

                    let timeFormatter = DateFormatter()
                    timeFormatter.timeStyle = .short
                    let timeString = timeFormatter.string(from: selectedTime)

                    var message = "Are you sure you want to send the meal data for \(timeString)?"

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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                sendMealCommand()
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
                case .validationError:
                    return Alert(
                        title: Text("Validation Error"),
                        message: Text(alertMessage ?? ""),
                        dismissButton: .default(Text("OK"))
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
        isLoading = true

        let calendar = Calendar.current
        let now = Date()
        let selectedDateComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        guard let scheduledDate = calendar.date(bySettingHour: selectedDateComponents.hour ?? 0,
                                                minute: selectedDateComponents.minute ?? 0,
                                                second: 0,
                                                of: now) else {
            isLoading = false
            statusMessage = "Invalid time selected."
            alertType = .statusFailure
            showAlert = true
            return
        }

        pushNotificationManager.sendMealPushNotification(
            carbs: carbs,
            protein: protein,
            fat: fat,
            scheduledTime: scheduledDate
        ) { success, errorMessage in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    statusMessage = "Meal command sent successfully."
                    carbs = HKQuantity(unit: .gram(), doubleValue: 0.0)
                    protein = HKQuantity(unit: .gram(), doubleValue: 0.0)
                    fat = HKQuantity(unit: .gram(), doubleValue: 0.0)
                    alertType = .statusSuccess
                } else {
                    statusMessage = errorMessage ?? "Failed to send meal command."
                    alertType = .statusFailure
                }
                showAlert = true
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func handleValidationError(_ message: String) {
        alertMessage = message
        alertType = .validationError
        showAlert = true
    }
}
