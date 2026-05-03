// LoopFollow
// WatchOverrideView.swift

import SwiftUI

struct WatchOverrideView: View {
    let config: WatchConfig
    @ObservedObject var bgFetcher: BGFetcher
    @State private var selectedOverride: OverridePreset?
    @State private var showConfirm = false
    @State private var showCancelConfirm = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let result = resultMessage {
                    Text(result)
                        .font(.system(size: 14))
                        .foregroundColor(isError ? .red : .green)
                        .multilineTextAlignment(.center)
                } else if showConfirm, let override = selectedOverride {
                    Text(override.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)

                    if let pct = override.percentage {
                        Text(String(format: "%.0f%%", pct))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    CrownConfirmView(label: "to activate") {
                        sendOverride(name: override.name)
                    }
                } else if showCancelConfirm {
                    Text("Cancel Override")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)

                    CrownConfirmView(label: "to cancel") {
                        cancelOverride()
                    }
                } else {
                    Text("⚡ Overrides")
                        .font(.system(size: 14, weight: .semibold))

                    if bgFetcher.overridePresets.isEmpty {
                        Text("No presets found.\nCheck Nightscout profile.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        ForEach(bgFetcher.overridePresets) { preset in
                            Button {
                                selectedOverride = preset
                                showConfirm = true
                            } label: {
                                HStack {
                                    Text(preset.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    if let pct = preset.percentage {
                                        Text(String(format: "%.0f%%", pct))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple.opacity(0.4))
                        }
                    }

                    Divider()

                    Button("Cancel Active Override") {
                        showCancelConfirm = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }

    private func sendOverride(name: String) {
        WatchRemoteService.sendOverride(name: name, config: config) { success, error in
            if success {
                resultMessage = "Override activated!"
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }

    private func cancelOverride() {
        WatchRemoteService.cancelOverride(config: config) { success, error in
            if success {
                resultMessage = "Override cancelled"
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }
}
