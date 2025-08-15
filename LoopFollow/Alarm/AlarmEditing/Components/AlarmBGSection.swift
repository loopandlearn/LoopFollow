// LoopFollow
// AlarmBGSection.swift

import HealthKit
import SwiftUI

struct AlarmBGSection: View {
    // MARK: – public parameters

    let header: String?
    let footer: String?
    let title: String
    let range: ClosedRange<Double>

    // MARK: – underlying optional binding

    @Binding private var value: Double?

    // MARK: – designated initialiser

    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        value: Binding<Double?>
    ) {
        self.header = header
        self.footer = footer
        self.title = title
        self.range = range
        _value = value
    }

    // MARK: – derived non-optional binding

    private var nonOptional: Binding<Double> {
        Binding(
            get: { value ?? range.lowerBound },
            set: { newVal in value = newVal }
        )
    }

    // MARK: – view

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            BGPicker(
                title: title,
                range: range,
                value: nonOptional
            )
        }
    }
}
