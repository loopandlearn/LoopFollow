// LoopFollow
// UnitsConfigurationView.swift

import SwiftUI

/// Reusable view for configuring units and metrics.
/// Can be embedded in Forms or used standalone during onboarding.
///
/// Onboarding splits this into two lighter pages — the glucose unit on its own,
/// and the LoopFollow statistics (range, glycemic, variability) on a second page
/// — by rendering a subset of the sections via `sections`. Settings shows them
/// all together (the default).
struct UnitsConfigurationView: View {
    /// Which groups of sections to render. Onboarding uses `.units` and
    /// `.statistics` on separate pages; everywhere else uses `.all`.
    struct Sections: OptionSet {
        let rawValue: Int
        /// Glucose display unit (mg/dL vs mmol/L).
        static let units = Sections(rawValue: 1 << 0)
        /// Range mode plus the glycemic and variability metrics.
        static let statistics = Sections(rawValue: 1 << 1)
        static let all: Sections = [.units, .statistics]
    }

    var sections: Sections = .all

    @State private var rangeMode = UnitSettingsStore.shared.timeInRangeMode
    @State private var glucoseUnit = UnitSettingsStore.shared.glucoseUnit
    @State private var lowValue = Storage.shared.lowLine.value
    @State private var highValue = Storage.shared.highLine.value

    /// Formats a mg/dL threshold pair in the currently selected glucose unit,
    /// e.g. "70–180" or "3.9–10.0".
    private func rangeBounds(_ lowMgdl: Double, _ highMgdl: Double) -> String {
        let factor = glucoseUnit == .mmolL ? GlucoseConversion.mgDlToMmolL : 1.0
        let digits = glucoseUnit.fractionDigits
        let low = Localizer.formatToLocalizedString(lowMgdl * factor, maxFractionDigits: digits, minFractionDigits: digits)
        let high = Localizer.formatToLocalizedString(highMgdl * factor, maxFractionDigits: digits, minFractionDigits: digits)
        return "\(low)–\(high)"
    }

    /// The mode's range in the selected unit; custom uses the user's own low and high.
    private func rangeBounds(for mode: TimeInRangeDisplayMode) -> String {
        let thresholds = mode.fixedThresholds ?? (lowValue, highValue)
        return rangeBounds(thresholds.low, thresholds.high)
    }

    var body: some View {
        Group {
            if sections.contains(.units) {
                unitsSections
            }
            if sections.contains(.statistics) {
                statisticsSections
            }
        }
    }

    @ViewBuilder
    private var unitsSections: some View {
        Section("Glucose") {
            Picker("Glucose Unit", selection: $glucoseUnit) {
                Text("mg/dL").tag(GlucoseDisplayUnit.mgdL)
                Text("mmol/L").tag(GlucoseDisplayUnit.mmolL)
            }
            .pickerStyle(.segmented)
            .onChange(of: glucoseUnit) { newValue in
                UnitSettingsStore.shared.glucoseUnit = newValue
            }
        }
    }

    @ViewBuilder
    private var statisticsSections: some View {
        Group {
            Section {
                NavigationLink {
                    RangeModeList(
                        selection: $rangeMode,
                        lowValue: $lowValue,
                        highValue: $highValue,
                        glucoseUnit: glucoseUnit,
                        bounds: rangeBounds(for:)
                    )
                } label: {
                    RangeModeRow(mode: rangeMode, bounds: rangeBounds(for: rangeMode))
                }
                .accessibilityLabel("Range Mode, \(rangeMode.title)")
            } header: {
                Text("Range")
            } footer: {
                Text("Cut-offs in \(glucoseUnit.rawValue).")
            }

            Section {
                Picker("Metric", selection: Binding(
                    get: { UnitSettingsStore.shared.glycemicMetricMode },
                    set: { UnitSettingsStore.shared.glycemicMetricMode = $0 }
                )) {
                    Text("eHbA1c").tag(GlycemicMetricMode.ehba1c)
                    Text("GMI").tag(GlycemicMetricMode.gmi)
                }
                .pickerStyle(.segmented)

                Picker("Output Unit", selection: Binding(
                    get: { UnitSettingsStore.shared.glycemicOutputUnit },
                    set: { UnitSettingsStore.shared.glycemicOutputUnit = $0 }
                )) {
                    Text("%").tag(GlycemicOutputUnit.percent)
                    Text("mmol/mol").tag(GlycemicOutputUnit.mmolMol)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Glycemic Metrics")
            } footer: {
                Text("eHbA1c — an A1c estimate from your average glucose. GMI — Glucose Management Indicator, another A1c estimate from average glucose. % and mmol/mol (IFCC) are two scales for the result.")
            }

            Section {
                Picker("Metric", selection: Binding(
                    get: { UnitSettingsStore.shared.variabilityMetricMode },
                    set: { UnitSettingsStore.shared.variabilityMetricMode = $0 }
                )) {
                    Text("Std Dev").tag(VariabilityMetricMode.stdDeviation)
                    Text("CV").tag(VariabilityMetricMode.cv)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Variability")
            } footer: {
                Text("Std Dev — Standard Deviation, how much glucose swings around the average. CV — Coefficient of Variation, that swing relative to the average (Std Dev ÷ mean).")
            }
        }
    }
}

/// A range mode's name with its cut-offs trailing, on one line.
private struct RangeModeRow: View {
    let mode: TimeInRangeDisplayMode
    let bounds: String

    var body: some View {
        HStack {
            Text(mode.title)
                .foregroundStyle(Color.primary)
            Spacer()
            // Color.secondary, not .secondary, which inside a Button is a shade of the tint.
            Text(bounds)
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
        }
        .lineLimit(1)
    }
}

/// Full-width list of range modes, so names and cut-offs fit on one line.
/// Picking a fixed mode goes back; picking custom stays to set its low and high.
private struct RangeModeList: View {
    @Binding var selection: TimeInRangeDisplayMode
    @Binding var lowValue: Double
    @Binding var highValue: Double
    let glucoseUnit: GlucoseDisplayUnit
    let bounds: (TimeInRangeDisplayMode) -> String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                ForEach(TimeInRangeDisplayMode.allCases, id: \.self) { mode in
                    Button {
                        selection = mode
                        if mode != .custom {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            RangeModeRow(mode: mode, bounds: bounds(mode))
                            // Always laid out so the cut-offs line up whichever row is selected.
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .opacity(selection == mode ? 1 : 0)
                        }
                    }
                    .accessibilityAddTraits(selection == mode ? .isSelected : [])
                }
            } footer: {
                Text("Cut-offs in \(glucoseUnit.rawValue).")
            }

            if selection == .custom {
                Section("Custom Range") {
                    BGPicker(
                        title: "Low",
                        range: 40 ... 120,
                        value: $lowValue
                    )
                    .id(glucoseUnit)
                    BGPicker(
                        title: "High",
                        range: 120 ... 400,
                        value: $highValue
                    )
                    .id(glucoseUnit)
                }
            }
        }
        .onChange(of: selection) { newValue in
            UnitSettingsStore.shared.timeInRangeMode = newValue
            Observable.shared.chartSettingsChanged.value = true
        }
        .onChange(of: lowValue) { newValue in
            Storage.shared.lowLine.value = newValue
            Observable.shared.chartSettingsChanged.value = true
        }
        .onChange(of: highValue) { newValue in
            Storage.shared.highLine.value = newValue
            Observable.shared.chartSettingsChanged.value = true
        }
        .navigationTitle("Range")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Standalone page for units configuration during onboarding.
/// Shows a checkmark button in the toolbar to complete setup.
struct UnitsOnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        Form {
            UnitsConfigurationView()
        }
        .navigationTitle("Set Up Units")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Storage.shared.hasConfiguredUnits.value = true
                    onComplete()
                }) {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
