// LoopFollow
// URLTokenValidationView.swift
// Created by codebymini.

import SwiftUI

struct URLTokenValidationView: View {
    let settings: RemoteCommandSettings
    let shouldPromptForURL: Bool
    let shouldPromptForToken: Bool
    let message: String
    let onConfirm: (RemoteCommandSettings) -> Void
    let onCancel: () -> Void

    init(
        settings: RemoteCommandSettings,
        shouldPromptForURL: Bool,
        shouldPromptForToken: Bool,
        message: String,
        onConfirm: @escaping (RemoteCommandSettings) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.settings = settings
        self.shouldPromptForURL = shouldPromptForURL
        self.shouldPromptForToken = shouldPromptForToken
        self.message = message
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        Form {
            Section {
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            // Show URL section if we have URL data
            if !settings.url.isEmpty {
                Section(header: Text("Nightscout URL")) {
                    HStack {
                        Text("Current URL:")
                        Spacer()
                        Text(Storage.shared.url.value.isEmpty ? "Not set" : Storage.shared.url.value)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Scanned URL:")
                        Spacer()
                        Text(settings.url)
                            .foregroundColor(.primary)
                    }
                }
            }

            // Show token section if we have token data
            if !settings.token.isEmpty {
                Section(header: Text("Access Token")) {
                    HStack {
                        Text("Current Token:")
                        Spacer()
                        Text(Storage.shared.token.value.isEmpty ? "Not set" : "••••••••")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Scanned Token:")
                        Spacer()
                        Text("••••••••")
                            .foregroundColor(.primary)
                    }
                }
            }

            Section {
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Confirm & Import") {
                        onConfirm(settings)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("URL/Token Validation")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Cancel") {
            onCancel()
        })
    }
}
