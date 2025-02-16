//
//  AdvancedSettingsView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-23.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: AdvancedSettingsViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Advanced Settings")) {
                    Toggle("Download Treatments", isOn: $viewModel.downloadTreatments)
                    Toggle("Download Prediction", isOn: $viewModel.downloadPrediction)
                    Toggle("Graph Basal", isOn: $viewModel.graphBasal)
                    Toggle("Graph Bolus", isOn: $viewModel.graphBolus)
                    Toggle("Graph Carbs", isOn: $viewModel.graphCarbs)
                    Toggle("Graph Other Treatments", isOn: $viewModel.graphOtherTreatments)
                }

                Section(header: Text("BG Delay Settings")) {
                    Toggle("Dynamic BG Delay", isOn: $viewModel.bgDelayDynamicEnabled)
                    if viewModel.bgDelayDynamicEnabled {
                        HStack {
                            Text("Dynamic BG Delay (Sec)")
                            Spacer()
                            Text("\(viewModel.bgDelayDynamicDelay, specifier: "%.0f")")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Stepper(value: $viewModel.bgUpdateDelay, in: 1...30, step: 1) {
                            Text("BG Update Delay (Sec): \(viewModel.bgUpdateDelay)")
                        }
                    }
                }

                Section(header: Text("Logging Options")) {
                    Toggle("Debug Log Level", isOn: $viewModel.debugLogLevel)
                }
            }
            .navigationBarTitle("Advanced Settings", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
