//
//  AlarmStepperSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AlarmStepperSection: View {
    let header: String?
    let footer: String?
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let unitLabel: String
    @Binding var value: Double

    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        step: Double,
        unitLabel: String,
        value: Binding<Double>
    ) {
        self.header = header
        self.footer = footer
        self.title = title
        self.range = range
        self.step = step
        self.unitLabel = unitLabel
        self._value = value
    }

/**
 header: Text(title),
 footer: Text("Set \(title), \(Int(range.lowerBound))–\(Int(range.upperBound)) \(unitLabel)")
 **/

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            Stepper(
                "\(title): \(Int(value)) \(unitLabel)",
                value: $value,
                in: range,
                step: step
            )
        }
    }
}
