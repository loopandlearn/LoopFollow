//
//  AlarmBGSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-06.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI
import HealthKit

struct AlarmBGSection: View {
    let header: String?
    let footer: String?
    let title: String
    let range: ClosedRange<Double>
    @Binding var value: Double

    @State private var showPicker = false

    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        value: Binding<Double>
    ) {
        self.header = header
        self.footer = footer
        self.title  = title
        self.range  = range
        self._value = value
    }
    
    private var unit: HKUnit { UserDefaultsRepository.getPreferredUnit() }

    private var displayValue: String {
        let formatted = Localizer.formatQuantity(value)
        return "\(formatted) \(unit.localizedShortUnitString)"
    }

    private var pickerValues: [Double] {
        let step : Double = unit == .millimolesPerLiter ? 18.0 * 0.1 : 1.0

        return stride(from: range.lowerBound, through: range.upperBound, by: step)
            .map { $0 }
    }

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
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
                            Text("\(Localizer.formatQuantity(v)) \(unit.localizedShortUnitString)")
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
