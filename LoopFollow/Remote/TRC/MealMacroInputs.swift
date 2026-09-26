// LoopFollow
// MealMacroInputs.swift

import HealthKit
import SwiftUI

/// Carbs, fat and protein rows bound to the remote guardrail maxima.
struct MealMacroInputs: View {
    @Binding var carbs: HKQuantity
    @Binding var fat: HKQuantity
    @Binding var protein: HKQuantity
    var showFatProtein: Bool
    @FocusState.Binding var carbsFocused: Bool
    @FocusState.Binding var fatFocused: Bool
    @FocusState.Binding var proteinFocused: Bool
    var onValidationError: (String) -> Void
    /// Values already in the meal stay editable even when they exceed the guardrail maxima.
    var currentValues: (carbs: HKQuantity, fat: HKQuantity, protein: HKQuantity)? = nil

    @ObservedObject private var maxCarbs = Storage.shared.maxCarbs
    @ObservedObject private var maxProtein = Storage.shared.maxProtein
    @ObservedObject private var maxFat = Storage.shared.maxFat

    var body: some View {
        HKQuantityInputView(
            label: "Carbs",
            quantity: $carbs,
            unit: .gram(),
            maxLength: 4,
            minValue: HKQuantity(unit: .gram(), doubleValue: 0),
            maxValue: ceiling(maxCarbs.value, currentValues?.carbs),
            isFocused: $carbsFocused,
            onValidationError: onValidationError
        )

        if showFatProtein {
            HKQuantityInputView(
                label: "Fat",
                quantity: $fat,
                unit: .gram(),
                maxLength: 4,
                minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                maxValue: ceiling(maxFat.value, currentValues?.fat),
                isFocused: $fatFocused,
                onValidationError: onValidationError
            )

            HKQuantityInputView(
                label: "Protein",
                quantity: $protein,
                unit: .gram(),
                maxLength: 4,
                minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                maxValue: ceiling(maxProtein.value, currentValues?.protein),
                isFocused: $proteinFocused,
                onValidationError: onValidationError
            )
        }
    }

    private func ceiling(_ limit: HKQuantity, _ current: HKQuantity?) -> HKQuantity {
        guard let current, current.compare(limit) == .orderedDescending else { return limit }
        return current
    }
}
