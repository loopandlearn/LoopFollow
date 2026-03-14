// LoopFollow
// APNSettingsView.swift

import SwiftUI

struct APNSettingsView: View {
    @State private var laEnabled: Bool = Storage.shared.laEnabled.value
    @State private var keyId: String = Storage.shared.lfKeyId.value
    @State private var apnsKey: String = Storage.shared.lfApnsKey.value

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
                    Button("Restart Live Activity") {
                        LiveActivityManager.shared.forceRestart()
                    }
                }
            }
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
