// LoopFollow
// InfoRowSettingsView.swift

import SwiftUI

struct InfoRowSettingsView: View {
    @Binding var item: InfoDisplayItem

    var body: some View {
        Form {
            Section {
                Toggle("Show in Info Display", isOn: $item.isVisible)
            }

            if item.type.isColorable {
                Section(
                    header: Text("Color"),
                    footer: Text(colorFooter)
                ) {
                    Toggle("Enable coloring", isOn: $item.coloring.enabled)

                    if item.coloring.enabled {
                        thresholdField(title: "Yellow at", value: $item.coloring.warning)
                        thresholdField(title: "Red at", value: $item.coloring.urgent)

                        if let thresholdWarning {
                            Label(thresholdWarning, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationBarTitle(item.type.name, displayMode: .inline)
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    /// Non-blocking sanity check: red should be more severe than yellow, in the
    /// metric's fixed direction. `nil` when consistent or a threshold is unset.
    private var thresholdWarning: String? {
        guard item.coloring.enabled,
              let warning = item.coloring.warning,
              let urgent = item.coloring.urgent
        else { return nil }
        switch item.type.colorDirection {
        case .above:
            return urgent < warning ? "Red should be at or above yellow." : nil
        case .below:
            return urgent > warning ? "Red should be at or below yellow." : nil
        }
    }

    private var colorFooter: String {
        switch item.type.colorDirection {
        case .above:
            return "The value turns yellow at or above the yellow level and red at or above the red level. In range it shows green. A visual cue only — it never triggers an alarm."
        case .below:
            return "The value turns yellow at or below the yellow level and red at or below the red level. In range it shows green. A visual cue only — it never triggers an alarm."
        }
    }

    private func thresholdField(title: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text(for: value))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            if let unit = item.type.colorUnitLabel {
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }

    /// Bridges an optional Double threshold to an editable text field.
    /// Empty text clears the threshold (that color is then unused); accepts both
    /// "." and "," as the decimal separator.
    private func text(for value: Binding<Double?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue.map { formatted($0) } ?? "" },
            set: { newText in
                let normalized = newText.replacingOccurrences(of: ",", with: ".")
                value.wrappedValue = normalized.isEmpty ? nil : Double(normalized)
            }
        )
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
