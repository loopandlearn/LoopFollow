// LoopFollow
// APNSettingsView.swift

import SwiftUI

struct APNSettingsView: View {
    @State private var keyId: String = Storage.shared.lfKeyId.value
    @State private var apnsKey: String = Storage.shared.lfApnsKey.value

    var body: some View {
        Form {
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
        }
        .onChange(of: keyId) { newValue in
            Storage.shared.lfKeyId.value = newValue
        }
        .onChange(of: apnsKey) { newValue in
            let apnsService = LoopAPNSService()
            Storage.shared.lfApnsKey.value = apnsService.validateAndFixAPNSKey(newValue)
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("APN")
        .navigationBarTitleDisplayMode(.inline)
    }
}
