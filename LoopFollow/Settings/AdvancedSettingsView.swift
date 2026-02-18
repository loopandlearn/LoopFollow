// LoopFollow
// AdvancedSettingsView.swift

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: AdvancedSettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Download Treatments", isOn: $viewModel.downloadTreatments)
                Toggle("Download Prediction", isOn: $viewModel.downloadPrediction)
                Toggle("Graph Basal", isOn: $viewModel.graphBasal)
                Toggle("Graph Bolus", isOn: $viewModel.graphBolus)
                Toggle("Graph Carbs", isOn: $viewModel.graphCarbs)
                Toggle("Graph Other Treatments", isOn: $viewModel.graphOtherTreatments)

                Stepper(value: $viewModel.bgUpdateDelay, in: 1 ... 30, step: 1) {
                    Text("BG Update Delay (Sec): \(viewModel.bgUpdateDelay)")
                }
            } header: {
                Label("Advanced Settings", systemImage: "gearshape.2")
            } footer: {
                Text("BG Update Delay adds a pause before fetching new readings to allow your CGM time to upload data.")
            }

            Section {
                Toggle("Debug Log Level", isOn: $viewModel.debugLogLevel)
            } header: {
                Label("Logging Options", systemImage: "doc.text.magnifyingglass")
            } footer: {
                Text("Enable Debug Log Level for detailed logging when troubleshooting issues. This may increase storage usage.")
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Advanced Settings", displayMode: .inline)
    }
}
