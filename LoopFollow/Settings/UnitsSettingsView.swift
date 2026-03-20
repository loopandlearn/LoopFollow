// LoopFollow
// UnitsSettingsView.swift

import SwiftUI

struct UnitsSettingsView: View {
    var body: some View {
        Form {
            UnitsConfigurationView()
        }
        .navigationTitle("Metrics and Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}
