// LoopFollow
// UnitsConfigurationView.swift

import SwiftUI

/// Reusable view for configuring units and metrics.
/// Can be embedded in Forms or used standalone during onboarding.
struct UnitsConfigurationView: View {
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
                Picker("Range Mode", selection: Binding(
                    get: { UnitSettingsStore.shared.timeInRangeMode },
                    set: { UnitSettingsStore.shared.timeInRangeMode = $0 }
                )) {
                    Text("Time In Range").tag(TimeInRangeDisplayMode.tir)
                    Text("Time In Tighter Range").tag(TimeInRangeDisplayMode.titr)
                }
                .pickerStyle(.segmented)
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
