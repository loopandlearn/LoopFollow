// LoopFollow
// AlarmBGLimitSection.swift
// Created by Jonas Björkert on 2025-05-14.

import SwiftUI

struct AlarmBGLimitSection: View {
    // ────────── Public API ──────────
    let header: String?
    let footer: String?
    let toggleText: String
    let pickerTitle: String
    let range: ClosedRange<Double>
    let defaultOnValue: Double

    @Binding var value: Double?
    // ────────────────────────────────

    init(
        header: String? = nil,
        footer: String? = nil,
        toggleText: String,
        pickerTitle: String,
        range: ClosedRange<Double>,
        defaultOnValue: Double? = nil,
        value: Binding<Double?>
    ) {
        self.header = header
        self.footer = footer
        self.toggleText = toggleText
        self.pickerTitle = pickerTitle
        self.range = range
        if let v = defaultOnValue, range.contains(v) {
            self.defaultOnValue = v
        } else {
            self.defaultOnValue = range.lowerBound
        }
        _value = value
    }

    // MARK: - Private bindings

    private var isOn: Binding<Bool> {
        Binding(
            get: { value != nil },
            set: { on in
                if on, value == nil { value = defaultOnValue }
                if !on { value = nil }
            }
        )
    }

    private var pickerValue: Binding<Double> {
        Binding(
            get: { value ?? defaultOnValue },
            set: { newVal in value = newVal }
        )
    }

    // MARK: - Body

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            Toggle(toggleText, isOn: isOn)

            if isOn.wrappedValue {
                BGPicker(
                    title: pickerTitle,
                    range: range,
                    value: pickerValue
                )
            }
        }
    }
}
