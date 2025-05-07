//
//  AlarmThresholdPickerSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-06.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct AlarmBGSection: View {
    // ── Public API ──────────────────────────────────────────────────────────────
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    // ── Private state ──────────────────────────────────────────────────────────
    @State private var showPicker = false

    // Preferred unit – mmol/L or mg/dL
    private var unit: HKUnit { UserDefaultsRepository.getPreferredUnit() }

    private var displayValue: String {
        Localizer.formatQuantity(value)
    }

    // Generate all selectable display values for the picker
    private var pickerValues: [Double] {
        let step : Double = unit == .millimolesPerLiter ? 18.0 * 0.1 : 1.0

        return stride(from: range.lowerBound, through: range.upperBound, by: step)
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
            NavigationStack {
                VStack {
                    Picker("", selection: bindingForPicker) {
                        ForEach(pickerValues, id: \.self) { v in
                            Text(Localizer.formatQuantity(v))
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
            }
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var bindingForPicker: Binding<Double> {
        Binding(
            get: {
                // pick the closest representable value
                pickerValues.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
            },
            set: { newVal in
                value = newVal // stored in mg/dL
            }
        )
    }
}
