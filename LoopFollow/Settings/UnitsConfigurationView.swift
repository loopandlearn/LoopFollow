// LoopFollow
// UnitsConfigurationView.swift

import SwiftUI

/// Reusable view for configuring units and metrics.
/// Can be embedded in Forms or used standalone during onboarding.
struct UnitsConfigurationView: View {
    @State private var rangeMode = UnitSettingsStore.shared.timeInRangeMode

    var body: some View {
        Group {
            Section("Glucose") {
                Picker("Glucose Unit", selection: Binding(
                    get: { UnitSettingsStore.shared.glucoseUnit },
                    set: { UnitSettingsStore.shared.glucoseUnit = $0 }
                )) {
                    Text("mg/dL").tag(GlucoseDisplayUnit.mgdL)
                    Text("mmol/L").tag(GlucoseDisplayUnit.mmolL)
                }
                .pickerStyle(.segmented)
            }

            Section("Range") {
                Picker("Range Mode", selection: $rangeMode) {
                    Text("TIR").tag(TimeInRangeDisplayMode.tir)
                    Text("TITR").tag(TimeInRangeDisplayMode.titr)
                    Text("Custom").tag(TimeInRangeDisplayMode.custom)
                }
                .pickerStyle(.segmented)
                .onChange(of: rangeMode) { newValue in
                    UnitSettingsStore.shared.timeInRangeMode = newValue
                    Observable.shared.chartSettingsChanged.value = true
                }

                if rangeMode == .custom {
                    BGPicker(
                        title: "Low",
                        range: 40 ... 120,
                        value: Binding(
                            get: { Storage.shared.lowLine.value },
                            set: {
                                Storage.shared.lowLine.value = $0
                                Observable.shared.chartSettingsChanged.value = true
                            }
                        )
                    )
                    BGPicker(
                        title: "High",
                        range: 120 ... 400,
                        value: Binding(
                            get: { Storage.shared.highLine.value },
                            set: {
                                Storage.shared.highLine.value = $0
                                Observable.shared.chartSettingsChanged.value = true
                            }
                        )
                    )
                }
            }

            Section("Glycemic Metrics") {
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
            }

            Section("Variability") {
                Picker("Metric", selection: Binding(
                    get: { UnitSettingsStore.shared.variabilityMetricMode },
                    set: { UnitSettingsStore.shared.variabilityMetricMode = $0 }
                )) {
                    Text("Std Dev").tag(VariabilityMetricMode.stdDeviation)
                    Text("CV").tag(VariabilityMetricMode.cv)
                }
                .pickerStyle(.segmented)
            }
        }
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
