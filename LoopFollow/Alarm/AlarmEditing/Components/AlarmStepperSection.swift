// LoopFollow
// AlarmStepperSection.swift

import SwiftUI

struct AlarmStepperSection: View {
    // MARK: – public parameters

    let header: String?
    let footer: String?
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let unitLabel: String?

    // MARK: – private binding (always Double?)

    @Binding
    private var value: Double?

    // MARK: – designated initialiser (Double?)

    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        step: Double,
        unitLabel: String? = nil,
        value: Binding<Double?>
    ) {
        self.header = header
        self.footer = footer
        self.title = title
        self.range = range
        self.step = step
        self.unitLabel = unitLabel
        _value = value
    }

    // MARK: – convenience initialiser (Int?)

    /// Same API but for **`Binding<Int?>`** — it bridges to Double internally.
    init(
        header: String? = nil,
        footer: String? = nil,
        title: String,
        range: ClosedRange<Double>,
        step: Double,
        unitLabel: String? = nil,
        value intValue: Binding<Int?>
    ) {
        self.init(
            header: header,
            footer: footer,
            title: title,
            range: range,
            step: step,
            unitLabel: unitLabel,
            value: Binding<Double?>(
                get: { intValue.wrappedValue.map(Double.init) },
                set: { newVal in intValue.wrappedValue = newVal.map(Int.init) }
            )
        )
    }

    // MARK: – derived non-optional Binding<Double>

    private var nonOptional: Binding<Double> {
        Binding(
            get: { value ?? range.lowerBound },
            set: { newVal in value = newVal }
        )
    }

    private var decimalPlaces: Int {
        // If step is a whole number (e.g., 1.0, 5.0), we want 0 decimal places.
        if step.truncatingRemainder(dividingBy: 1) == 0 {
            return 0
        }
        // Otherwise, count characters after the decimal in the step value.
        let stepString = String(step)
        if let decimalIndex = stepString.firstIndex(of: ".") {
            return stepString.distance(from: stepString.index(after: decimalIndex), to: stepString.endIndex)
        }
        return 1 // Fallback to 1
    }

    // MARK: – view

    var body: some View {
        Section(
            header: header.map(Text.init),
            footer: footer.map(Text.init)
        ) {
            Stepper(value: nonOptional, in: range, step: step) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(
                        String(format: "%.\(decimalPlaces)f", nonOptional.wrappedValue) +
                            (unitLabel.map { " \($0)" } ?? "")
                    )
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}
