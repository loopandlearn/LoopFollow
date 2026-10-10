// LoopFollow
// AlarmBGLimitSection.swift

import SwiftUI

struct AlarmBGLimitSection: View {
    // ────────── Public API ──────────
    let header: LocalizedStringKey?
    let footer: LocalizedStringKey?
    let toggleText: String
    let pickerTitle: LocalizedStringKey
    let range: ClosedRange<Double>
    let defaultOnValue: Double

    @Binding var value: Double?
    // ────────────────────────────────

    init(
        header: LocalizedStringKey? = nil,
        footer: LocalizedStringKey? = nil,
        toggleText: String,
        pickerTitle: LocalizedStringKey,
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
            header: header.map { Text($0) },
            footer: footer.map { Text($0) }
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
