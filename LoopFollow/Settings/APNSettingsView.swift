// LoopFollow
// APNSettingsView.swift

import SwiftUI

struct APNSettingsView: View {
    @State private var laEnabled: Bool = Storage.shared.laEnabled.value
    @State private var keyId: String = Storage.shared.lfKeyId.value
    @State private var apnsKey: String = Storage.shared.lfApnsKey.value
    @State private var restartConfirmed = false

    var body: some View {
        Form {
            Section(header: Text("Live Activity")) {
                Toggle("Enable Live Activity", isOn: $laEnabled)
            }

            if laEnabled {
                Section(header: Text("LoopFollow APNs Credentials")) {
                    HStack {
                        Text("APNS Key ID")
                        TogglableSecureInput(
                            placeholder: "Enter APNS Key ID",
                            text: $keyId,
                            style: .singleLine
                        )
                    }

                    VStack(alignment: .leading) {
                        Text("APNS Key")
                        TogglableSecureInput(
                            placeholder: "Paste APNS Key",
                            text: $apnsKey,
                            style: .multiLine
                        )
                        .frame(minHeight: 110)
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
        .onChange(of: laEnabled) { newValue in
            Storage.shared.laEnabled.value = newValue
            if !newValue {
                LiveActivityManager.shared.end(dismissalPolicy: .immediate)
            }
        }
        .onChange(of: keyId) { newValue in
            Storage.shared.lfKeyId.value = newValue
        }
        .onChange(of: apnsKey) { newValue in
            let apnsService = LoopAPNSService()
            Storage.shared.lfApnsKey.value = apnsService.validateAndFixAPNSKey(newValue)
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}
