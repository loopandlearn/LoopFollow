//
//  AlarmThresholdPickerSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-06.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct AlarmThresholdRow: View {
    // ── Public API ──────────────────────────────────────────────────────────────
    let title: String
    let range: ClosedRange<Double>
    let step: Double          // 1 for mg/dL, 0.1 for mmol/L
    @Binding var value: Double   // **stored in mg/dL**

    // ── Private state ──────────────────────────────────────────────────────────
    @State private var showPicker = false

    // Preferred unit – mmol/L or mg/dL
    private var unit: HKUnit { UserDefaultsRepository.getPreferredUnit() }

    private var displayValue: String {
        format(value, in: unit)
    }

    // Generate all selectable display values for the picker
    private var pickerValues: [Double] {
        stride(from: range.lowerBound, through: range.upperBound, by: step)
            .map { $0 }
    }

    var body: some View {
        Section {
            // Collapsed row
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { showPicker = true }
        }
        .sheet(isPresented: $showPicker) {
            // Expanded wheel picker
            NavigationStack {
                VStack {
                    Picker("", selection: bindingForPicker) {
                        ForEach(pickerValues, id: \.self) { v in
                            Text(format(v, in: unit))
                                .tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPicker = false }
                    }
                }
            }   .presentationDetents([.fraction(0.35), .medium])   // 35 % or medium height
                .presentationDragIndicator(.visible)               // the little grab-bar
        }
    }

    // MARK: – Helpers
    private func format(_ mgdl: Double, in unit: HKUnit) -> String {
        if unit == .millimolesPerLiter {
            let mmol = mgdl / 18.0
            return String(format: "%.1f mmol/L", mmol)
        } else {
            return String(format: "%.0f mg/dL", mgdl)
        }
    }

    // Bind the picker directly to `value`, snapping to the closest choice
    private var bindingForPicker: Binding<Double> {
        Binding(
            get: {
                // pick the closest representable value
                pickerValues.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
            },
            set: { newVal in
                value = newVal    // stored in mg/dL
            }
        )
    }
}
