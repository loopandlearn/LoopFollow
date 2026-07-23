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

            if let config = item.type.colorConfig {
                Section(
                    header: Text("Color"),
                    footer: Text(colorFooter(config))
                ) {
                    Toggle("Enable coloring", isOn: enabledBinding(config))

                    if item.coloring.enabled {
                        thresholdRow(title: "Yellow at", value: $item.coloring.warning, default: config.defaultWarning, config: config)
                        thresholdRow(title: "Red at", value: $item.coloring.urgent, default: config.defaultUrgent, config: config)

                        if let thresholdWarning = thresholdWarning(config) {
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

    /// Turning coloring on seeds any unset threshold, so the steppers and the
    /// stored values always agree.
    private func enabledBinding(_ config: InfoColorConfig) -> Binding<Bool> {
        Binding(
            get: { item.coloring.enabled },
            set: { isOn in
                if isOn {
                    item.coloring.warning = item.coloring.warning ?? config.defaultWarning
                    item.coloring.urgent = item.coloring.urgent ?? config.defaultUrgent
                }
                item.coloring.enabled = isOn
            }
        )
    }

    private func thresholdRow(title: String, value: Binding<Double?>, default defaultValue: Double, config: InfoColorConfig) -> some View {
        SettingsStepperRow(
            title: title,
            range: config.range,
            step: config.step,
            value: Binding(
                get: { value.wrappedValue ?? defaultValue },
                set: { value.wrappedValue = $0 }
            ),
            format: { formatted($0, config) }
        )
    }

    private func formatted(_ value: Double, _ config: InfoColorConfig) -> String {
        let number = Localizer.formatToLocalizedString(
            value,
            maxFractionDigits: config.fractionDigits,
            minFractionDigits: config.fractionDigits
        )
        return "\(number) \(config.unit)"
    }

    /// Non-blocking sanity check: red should be more severe than yellow, in the
    /// metric's fixed direction. `nil` when consistent or a threshold is unset.
    private func thresholdWarning(_ config: InfoColorConfig) -> String? {
        guard item.coloring.enabled,
              let warning = item.coloring.warning,
              let urgent = item.coloring.urgent
        else { return nil }
        switch config.direction {
        case .above:
            return urgent < warning ? "Red should be at or above yellow." : nil
        case .below:
            return urgent > warning ? "Red should be at or below yellow." : nil
        }
    }

    private func colorFooter(_ config: InfoColorConfig) -> String {
        switch config.direction {
        case .above:
            return "The value turns yellow at or above the yellow level and red at or above the red level. In range it shows green. A visual cue only — it never triggers an alarm."
        case .below:
            return "The value turns yellow at or below the yellow level and red at or below the red level. In range it shows green. A visual cue only — it never triggers an alarm."
        }
    }
}
