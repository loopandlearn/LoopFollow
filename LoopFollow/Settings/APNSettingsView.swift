// LoopFollow
// APNSettingsView.swift

import SwiftUI

struct APNSettingsView: View {
    @State private var keyId: String = Storage.shared.lfKeyId.value
    @State private var apnsKey: String = Storage.shared.lfApnsKey.value

    private var keyIdValid: Bool {
        APNsCredentialValidator.isValidKeyId(keyId)
    }

    private var apnsKeyValid: Bool {
        APNsCredentialValidator.isValidApnsKey(apnsKey)
    }

    var body: some View {
        Form {
            Section(header: Text("LoopFollow APNs Credentials")) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("APNS Key ID")
                        TogglableSecureInput(
                            placeholder: "Enter APNS Key ID",
                            text: $keyId,
                            style: .singleLine
                        )
                        if !keyId.isEmpty {
                            Image(systemName: keyIdValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(keyIdValid ? .green : .orange)
                                .accessibilityLabel(keyIdValid ? "Valid Key ID" : "Invalid Key ID")
                        }
                    }
                    if !keyId.isEmpty, !keyIdValid {
                        Text("Key ID must be exactly 10 uppercase letters or digits.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("APNS Key")
                        Spacer()
                        if !apnsKey.isEmpty {
                            Image(systemName: apnsKeyValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(apnsKeyValid ? .green : .orange)
                                .accessibilityLabel(apnsKeyValid ? "Valid APNs key" : "Invalid APNs key")
                        }
                    }
                    TogglableSecureInput(
                        placeholder: "Paste APNS Key",
                        text: $apnsKey,
                        style: .multiLine
                    )
                    .frame(minHeight: 110)
                    if !apnsKey.isEmpty, !apnsKeyValid {
                        Text("Paste the full .p8 contents — must include the BEGIN PRIVATE KEY and END PRIVATE KEY lines.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .onChange(of: keyId) { newValue in
            Storage.shared.lfKeyId.value = newValue
        }
        .onChange(of: apnsKey) { newValue in
            let apnsService = LoopAPNSService()
            let normalized = apnsService.validateAndFixAPNSKey(newValue)
            Storage.shared.lfApnsKey.value = normalized
            // Reflect normalization (whitespace fixes etc.) in the field so the
            // green badge appears when paste added stray whitespace around an
            // otherwise-valid key.
            if normalized != newValue {
                apnsKey = normalized
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("APN")
        .navigationBarTitleDisplayMode(.inline)
    }
}
