// LoopFollow
// LoopNightscoutRemoteView.swift
// Created by Jonas Björkert.

import SwiftUI

struct LoopNightscoutRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var nsAdmin = Storage.shared.nsWriteAuth
    @ObservedObject var loopRemoteSetup = Storage.shared.loopRemoteSetup

    var body: some View {
        NavigationView {
            if !nsAdmin.value {
                ErrorMessageView(
                    message: "Please update your token to include the 'admin' role in order to do remote commands with Loop."
                )
            } else {
                VStack {
                    let columns = [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                    ]

                    LazyVGrid(columns: columns, spacing: 16) {
                        // Always show Overrides (uses existing Nightscout credentials)
                        CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: LoopOverrideView())

                        if !loopRemoteSetup.value {
                            // Show setup button if QR code not configured
                            CommandButtonView(command: "Add Remote Commands", iconName: "qrcode.viewfinder", destination: LoopRemoteSetupView())
                        } else {
                            // Show remote command buttons if QR code configured
                            CommandButtonView(command: "Carbs", iconName: "leaf.fill", destination: LoopRemoteCarbsView())
                            CommandButtonView(command: "Insulin", iconName: "drop.fill", destination: LoopRemoteInsulinView())
                        }
                    }
                    .padding(.horizontal)

                    if loopRemoteSetup.value {
                        Button(action: clearRemoteSetup) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Remote Setup")
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.top, 20)
                    }

                    Spacer()
                }
                .navigationBarTitle("Loop Remote Control", displayMode: .inline)
            }
        }
    }

    private func clearRemoteSetup() {
        // Clear the QR code URL and mark setup as incomplete
        Storage.shared.loopQrCodeURL.value = ""
        Storage.shared.loopRemoteSetup.value = false
    }
}
