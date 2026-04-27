// LoopFollow
// LiveActivitySettingsView.swift

import SwiftUI

struct LiveActivitySettingsView: View {
    @State private var laEnabled: Bool = Storage.shared.laEnabled.value
    @State private var restartConfirmed = false
    @State private var keyId: String = Storage.shared.lfKeyId.value
    @State private var apnsKey: String = Storage.shared.lfApnsKey.value

    private var apnsConfigured: Bool {
        APNsCredentialValidator.isFullyConfigured(keyId: keyId, apnsKey: apnsKey)
    }

    var body: some View {
        Form {
            Section(
                header: Text("Live Activity"),
                footer: Text("Live Activity updates require APNs credentials. Configure them in Settings → APN.")
            ) {
                Toggle("Enable Live Activity", isOn: $laEnabled)
            }

            if laEnabled {
                if !apnsConfigured {
                    Section {
                        Label {
                            Text("APNs credentials are missing or invalid — Live Activity updates will not work. Open Settings → APN to fix.")
                                .font(.callout)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }

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
        .onReceive(Storage.shared.lfKeyId.$value) { newValue in
            if newValue != keyId { keyId = newValue }
        }
        .onReceive(Storage.shared.lfApnsKey.$value) { newValue in
            if newValue != apnsKey { apnsKey = newValue }
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
