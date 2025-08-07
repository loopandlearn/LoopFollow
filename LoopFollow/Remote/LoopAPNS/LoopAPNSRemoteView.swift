// LoopFollow
// LoopAPNSRemoteView.swift
// Created by codebymini.

import SwiftUI

struct LoopAPNSRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = RemoteSettingsViewModel()

    var body: some View {
        NavigationView {
            VStack {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ]

                if viewModel.loopAPNSSetup {
                    // Show Loop APNS command buttons if APNS setup configured
                    LazyVGrid(columns: columns, spacing: 16) {
                        CommandButtonView(command: "Meal", iconName: "fork.knife", destination: LoopAPNSCarbsView())
                        CommandButtonView(command: "Bolus", iconName: "syringe", destination: LoopAPNSBolusView())
                        CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: OverridePresetsView())
                    }
                    .padding(.horizontal)
                } else {
                    // Show setup message if APNS is not configured - use full screen
                    VStack(spacing: 32) {
                        Spacer()

                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)

                        VStack(spacing: 16) {
                            Text("Loop APNS Not Configured")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Please configure Loop APNS settings in Remote Settings to use APNS commands.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                        }

                        NavigationLink(destination: RemoteSettingsView(viewModel: viewModel)) {
                            HStack(spacing: 12) {
                                Image(systemName: "gear")
                                    .font(.system(size: 18))
                                Text("Configure Loop APNS")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                Spacer()
            }
            .navigationBarTitle("Loop Remote Control", displayMode: .inline)
        }
    }
}
