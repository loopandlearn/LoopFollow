//
//  HKQuantityInputView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-09-17.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import SwiftUI
import HealthKit

struct HKQuantityInputView: View {
    var label: String
    @Binding var quantity: HKQuantity
    var unit: HKUnit
    var maxLength: Int
    var minValue: HKQuantity
    var maxValue: HKQuantity
    @FocusState.Binding var isFocused: Bool

    var onValidationError: (String) -> Void

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextFieldWithToolBar(
                quantity: $quantity,
                maxLength: maxLength,
                unit: unit,
                minValue: minValue,
                maxValue: maxValue,
                onValidationError: onValidationError
            )
            .focused($isFocused)
            Text(unit.localizedShortUnitString)
                .foregroundColor(.secondary)
        }
    }
}
