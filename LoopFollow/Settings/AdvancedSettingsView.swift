// LoopFollow
// AdvancedSettingsView.swift

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: AdvancedSettingsViewModel

    var body: some View {
        Form {
            Section("Advanced Settings") {
                Toggle("Download Treatments", isOn: $viewModel.downloadTreatments)
                Toggle("Download Prediction", isOn: $viewModel.downloadPrediction)
                Toggle("Graph Basal", isOn: $viewModel.graphBasal)
                Toggle("Graph Bolus", isOn: $viewModel.graphBolus)
                Toggle("Graph Carbs", isOn: $viewModel.graphCarbs)
                Toggle("Graph Other Treatments", isOn: $viewModel.graphOtherTreatments)

                Stepper(value: $viewModel.bgUpdateDelay, in: 1 ... 30, step: 1) {
                    Text("BG Update Delay (Sec): \(viewModel.bgUpdateDelay)")
                }
            }

            Section("Logging Options") {
                Toggle("Debug Log Level", isOn: $viewModel.debugLogLevel)
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Advanced Settings", displayMode: .inline)
    }
}
