// LoopFollow
// AAPSProfileView.swift

import SwiftUI

struct AAPSProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var selectedAction = "STATUS"
    @State private var profileName = ""

    enum AlertType {
        case success
        case error
    }

    private let profileActions = [
        ("STATUS", "Profile Status"),
        ("LIST", "List Profiles"),
        ("SWITCH", "Switch Profile"),
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current OTP Code Display
                VStack(spacing: 8) {
                    Text("Current OTP Code")
                        .font(.headline)

                    if let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.aapsQrCodeURL.value) {
                        Text(otpCode)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    } else {
                        Text("Invalid QR Code")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Form {
                    Section(header: Text("Profile Action")) {
                        Picker("Profile Action", selection: $selectedAction) {
                            ForEach(profileActions, id: \.0) { action, label in
                                Text(label).tag(action)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    if selectedAction == "SWITCH" {
                        Section(header: Text("Profile Name")) {
                            TextField("Enter profile name", text: $profileName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }

                    Section {
                        Button(action: {
                            sendProfileCommand()
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle")
                                    .font(.title2)
                                Text("Send Profile Command")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || !AAPSRemoteService.shared.validateSetup() || (selectedAction == "SWITCH" && profileName.isEmpty))
                    }
                }

                if isLoading {
                    ProgressView("Sending profile command...")
                        .padding()
                }
            }
            .navigationTitle("AndroidAPS Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendProfileCommand() {
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.aapsQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            showAlert = true
            return
        }

        if selectedAction == "SWITCH", profileName.isEmpty {
            alertMessage = "Please enter a profile name"
            alertType = .error
            showAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                let profile = selectedAction == "SWITCH" ? profileName : nil
                let success = try await AAPSRemoteService.shared.sendProfileCommand(action: selectedAction, profile: profile, otp: otpCode)
                await MainActor.run {
                    isLoading = false
                    if success {
                        alertType = .success
                        alertMessage = "Profile command sent successfully"
                    } else {
                        alertType = .error
                        alertMessage = "Failed to send profile command"
                    }
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertType = .error
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    AAPSProfileView()
}
