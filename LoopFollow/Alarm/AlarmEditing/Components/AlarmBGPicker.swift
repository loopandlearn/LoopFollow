// LoopFollow
// AlarmBGPicker.swift
// Created by Jonas Björkert on 2025-05-14.

import HealthKit
import SwiftUI

struct AlarmBGPicker: View {
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    private var unit: HKUnit { UserDefaultsRepository.getPreferredUnit() }

    private var allValues: [Double] {
        if unit == .millimolesPerLiter {
            let step = 0.1
            let lower = ceil((range.lowerBound / 18) / step) * step
            let upper = floor((range.upperBound / 18) / step) * step
            return stride(from: lower, through: upper, by: step).map { $0 * 18 }
        } else {
            return Array(stride(from: range.lowerBound, through: range.upperBound, by: 1))
        }
    }

    private var snappedValue: Binding<Double> {
        Binding(
            get: {
                allValues.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
            },
            set: { value = $0 }
        )
    }

    var body: some View {
        Picker(selection: snappedValue,
               label: HStack { Text(title) })
        {
            ForEach(allValues, id: \.self) { v in
                Text("\(Localizer.formatQuantity(v)) \(unit.localizedShortUnitString)")
                    .tag(v)
            }
        }
    }
}
