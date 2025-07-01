// LoopFollow
// BGPicker.swift
// Created by Jonas Björkert.

import HealthKit
import SwiftUI

/// Lets the user pick a BG-related number (mg/dL or mmol/L) inside any form row.
struct BGPicker: View {
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    // MARK: – Helpers

    private var unit: HKUnit { Localizer.getPreferredUnit() }

    private var allValues: [Double] {
        if unit == .millimolesPerLiter {
            let step = 0.1
            let lower = ceil((range.lowerBound / 18) / step) * step
            let upper = floor((range.upperBound / 18) / step) * step
            return stride(from: lower, through: upper, by: step).map { $0 * 18 }
        } else {
            return Array(stride(from: range.lowerBound,
                                through: range.upperBound,
                                by: 1))
        }
    }

    private var snappedValue: Binding<Double> {
        Binding(
            get: { allValues.min(by: { abs($0 - value) < abs($1 - value) }) ?? value },
            set: { value = $0 }
        )
    }

    var body: some View {
        Picker(selection: snappedValue) {
            ForEach(allValues, id: \.self) { v in
                Text("\(Localizer.formatQuantity(v)) \(unit.localizedShortUnitString)")
                    .tag(v)
            }
        } label: {
            Text(title)
        }
    }
}
