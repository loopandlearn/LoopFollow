// LoopFollow
// LoopAPNSRemoteView.swift
// Created by codebymini.

import SwiftUI

struct LoopAPNSRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var loopAPNSSetup = Storage.shared.loopAPNSSetup
    @StateObject private var viewModel = RemoteSettingsViewModel()

    var body: some View {
        NavigationView {
            VStack {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    if loopAPNSSetup.value {
                        // Show Loop APNS command buttons if APNS setup configured
                        CommandButtonView(command: "Meal", iconName: "fork.knife", destination: LoopAPNSCarbsView())
                        CommandButtonView(command: "Bolus", iconName: "syringe", destination: LoopAPNSBolusView())
                        CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: OverridePresetsView())
                    } else {
                        // Show setup message if APNS is not configured
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)

                            Text("Loop APNS Not Configured")
                                .font(.headline)

                            Text("Please configure Loop APNS settings in Remote Settings to use APNS commands.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)

                            NavigationLink(destination: LoopAPNSSettingsView(viewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Configure Loop APNS")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationBarTitle("Loop Remote Control", displayMode: .inline)
            .onAppear {
                // Validate Loop APNS setup when view appears
                viewModel.validateFullLoopAPNSSetup()
            }
        }
    }
}
