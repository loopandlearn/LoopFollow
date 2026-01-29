// LoopFollow
// SettingsStepperRow.swift

import SwiftUI

struct SettingsStepperRow<Value: Strideable & Comparable>: View
    where Value.Stride: SignedNumeric & Comparable
{
    let title: String
    let range: ClosedRange<Value>
    let step: Value.Stride

    private let format: (Value) -> String

    @Binding private var value: Value

    init(
        title: String,
        range: ClosedRange<Value>,
        step: Value.Stride,
        value: Binding<Value>,
        format: @escaping (Value) -> String = { "\($0)" }
    ) {
        self.title = title
        self.range = range
        self.step = step
        _value = value
        self.format = format
    }

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .foregroundColor(.secondary)
            }
        }
    }
}
