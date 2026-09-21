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
            maxValue: maxCarbs.value,
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
                maxValue: maxFat.value,
                isFocused: $fatFocused,
                onValidationError: onValidationError
            )

            HKQuantityInputView(
                label: "Protein",
                quantity: $protein,
                unit: .gram(),
                maxLength: 4,
                minValue: HKQuantity(unit: .gram(), doubleValue: 0),
                maxValue: maxProtein.value,
                isFocused: $proteinFocused,
                onValidationError: onValidationError
            )
        }
    }
}
