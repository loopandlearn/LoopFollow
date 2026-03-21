// LoopFollow
// UnitsSettingsView.swift

import SwiftUI

struct UnitsSettingsView: View {
    var body: some View {
        Form {
            UnitsConfigurationView()
        }
        .navigationTitle("Units and Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }
}
