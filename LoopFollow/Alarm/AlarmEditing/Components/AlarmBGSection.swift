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
    let header:  String?
    let footer:  String?
    let title:   String
    let range:   ClosedRange<Double>
    @Binding var value: Double

    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        value: Binding<Double>
    ) {
        self.header = header
        self.footer = footer
        self.title = title
        self.range = range
        self._value = value
    }

    private var unit: HKUnit { UserDefaultsRepository.getPreferredUnit() }

    private var displayValue: String {
        "\(Localizer.formatQuantity(value)) \(unit.localizedShortUnitString)"
    }

    private var allValues: [Double] {
        if unit == .millimolesPerLiter {
            let stepMMOL = 0.1
            let lower = ceil((range.lowerBound / 18) / stepMMOL) * stepMMOL
            let upper = floor((range.upperBound / 18) / stepMMOL) * stepMMOL

            return stride(from: lower, through: upper, by: stepMMOL).map { $0 * 18 }
        } else {
            return Array(stride(from: range.lowerBound, through: range.upperBound, by: 1))
        }
    }

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            Picker(
                selection: $value,
                label: HStack {
                    Text(title)
                }
            ) {
                ForEach(allValues, id: \.self) { v in
                    Text("\(Localizer.formatQuantity(v)) \(unit.localizedShortUnitString)")
                        .tag(v)
                }
            }
        }
    }
}
