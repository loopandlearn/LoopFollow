// LoopFollow
// LoopAPNSRemoteView.swift

import SwiftUI

struct LoopAPNSRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = RemoteSettingsViewModel()
    @ObservedObject private var activeOverrideNote = Observable.shared.override
    @ObservedObject private var remoteCommands = Storage.shared.remoteCommands
    @ObservedObject private var loopRemoteCommands = Storage.shared.loopRemoteCommands

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
                        CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: OverridePresetsView(), isActive: activeOverrideNote.value != nil)
                        if ProfileRemote.loop.supportsAny(in: ProfileRemote.loop.acceptedCommands(profileDocument: remoteCommands.value, loopDeviceStatus: loopRemoteCommands.value)) {
                            CommandButtonView(command: "Profiles", iconName: "arrow.triangle.2.circlepath", destination: TherapyProfilesView(remote: .loop))
                        } else {
                            UnavailableCommandButtonView(
                                command: "Profiles",
                                iconName: "arrow.triangle.2.circlepath",
                                title: "Profiles Not Available",
                                message: "Loop has not said it accepts profile commands. It does once it has a pump and a maximum basal rate set up and can receive remote commands. An older Loop also needs the Profile Save & Load customization, added with the Loop and Learn Customization Select script."
                            )
                        }
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

/// A remote command button for a command the connected Loop build does not offer.
struct UnavailableCommandButtonView: View {
    let command: String
    let iconName: String
    let title: String
    let message: String

    @State private var showInfo = false

    var body: some View {
        Button {
            showInfo = true
        } label: {
            VStack {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                Text(command)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(Color.gray.opacity(0.35))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .alert(isPresented: $showInfo) {
            Alert(title: Text(title), message: Text(message), dismissButton: .default(Text("OK")))
        }
    }
}
