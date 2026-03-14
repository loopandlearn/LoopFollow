// LoopFollow
// LiveActivitySettingsView.swift

import SwiftUI

struct LiveActivitySettingsView: View {
    @State private var laEnabled: Bool = Storage.shared.laEnabled.value
    @State private var restartConfirmed = false

    var body: some View {
        Form {
            Section(header: Text("Live Activity")) {
                Toggle("Enable Live Activity", isOn: $laEnabled)
            }

            if laEnabled {
                Section {
                    Button(restartConfirmed ? "Live Activity Restarted" : "Restart Live Activity") {
                        LiveActivityManager.shared.forceRestart()
                        restartConfirmed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            restartConfirmed = false
                        }
                    }
                    .disabled(restartConfirmed)
                }
            }
        }
        .onReceive(Storage.shared.laEnabled.$value) { newValue in
            if newValue != laEnabled { laEnabled = newValue }
        }
        .onChange(of: laEnabled) { newValue in
            Storage.shared.laEnabled.value = newValue
            if !newValue {
                LiveActivityManager.shared.end(dismissalPolicy: .immediate)
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}
