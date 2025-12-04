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

    // Bolus calculator state
    @State private var carbsForCalculation = ""
    @State private var calculatedBolusFromCarbs: Double? = nil
    @State private var isCalculatorExpanded = true
    @State private var recentCarbSuggestion: (carbs: Double, bolus: Double, minutesAgo: Int)? = nil
    @FocusState private var carbsFieldIsFocused: Bool

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
                    // Bolus calculator section (collapsible)
                    Section(header:
                        Button(action: {
                            withAnimation {
                                isCalculatorExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Text("Bolus Calculator")
                                Spacer()
                                Image(systemName: isCalculatorExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    ) {
                        if isCalculatorExpanded {
                            HStack {
                                Text("Carbs")
                                Spacer()
                                TextField("0", text: $carbsForCalculation)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($carbsFieldIsFocused)
                                    .onChange(of: carbsForCalculation) { newValue in
                                        // Only allow numbers and decimal point
                                        let filtered = newValue.filter { "0123456789.".contains($0) }
                                        // Ensure only one decimal point
                                        let components = filtered.components(separatedBy: ".")
                                        if components.count > 2 {
                                            carbsForCalculation = String(filtered.dropLast())
                                        } else {
                                            carbsForCalculation = filtered
                                        }

                                        // Calculate bolus from carbs
                                        if let carbsValue = Double(carbsForCalculation), carbsValue > 0 {
                                            calculatedBolusFromCarbs = BolusCalculatorHelper.shared.calculateBolusFromCarbs(carbsValue)
                                        } else {
                                            calculatedBolusFromCarbs = nil
                                        }
                                    }
                                Text("g")
                                    .foregroundColor(.secondary)
                            }

                            if let calculatedBolus = calculatedBolusFromCarbs {
                                Button(action: {
                                    applyCalculatedBolus()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Calculated: \(String(format: "%.2f", calculatedBolus))U")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if let carbRatio = BolusCalculatorHelper.shared.getCurrentCarbRatio() {
                                                Text("Using carb ratio: 1U per \(String(format: "%.1f", carbRatio))g")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else if !carbsForCalculation.isEmpty {
                                Text("Enter valid carb amount to calculate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if BolusCalculatorHelper.shared.getCurrentCarbRatio() == nil && !carbsForCalculation.isEmpty {
                                Text("⚠️ Carb ratio not available from profile")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

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
            .onAppear {
                loadRecentCarbSuggestion()

                // Auto-populate carbs field if recent carb entry exists
                if let suggestion = recentCarbSuggestion {
                    carbsForCalculation = String(format: "%.0f", suggestion.carbs)
                    // Trigger calculation
                    if let carbsValue = Double(carbsForCalculation), carbsValue > 0 {
                        calculatedBolusFromCarbs = BolusCalculatorHelper.shared.calculateBolusFromCarbs(carbsValue)
                    }
                }
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

    private func loadRecentCarbSuggestion() {
        // Load recent carb suggestion
        recentCarbSuggestion = BolusCalculatorHelper.shared.getSuggestedBolusFromRecentCarbs()
    }

    private func applyCalculatedBolus() {
        guard let calculatedBolus = calculatedBolusFromCarbs else { return }
        bolusAmount = HKQuantity(unit: .internationalUnit(), doubleValue: calculatedBolus)
        carbsFieldIsFocused = false
    }
}
