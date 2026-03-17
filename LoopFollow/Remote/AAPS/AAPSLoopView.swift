// LoopFollow
// AAPSLoopView.swift

import SwiftUI

struct AAPSLoopView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var selectedAction = "START"

    enum AlertType {
        case success
        case error
    }

    private let loopActions = [
        ("START", "Start Loop"),
        ("STOP", "Stop Loop"),
        ("STATUS", "Loop Status"),
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
                    Section(header: Text("Loop Action")) {
                        Picker("Loop Action", selection: $selectedAction) {
                            ForEach(loopActions, id: \.0) { action, label in
                                Text(label).tag(action)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section {
                        Button(action: {
                            sendLoopCommand()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.title2)
                                Text("Send Loop Command")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || !AAPSRemoteService.shared.validateSetup())
                    }
                }

                if isLoading {
                    ProgressView("Sending loop command...")
                        .padding()
                }
            }
            .navigationTitle("AndroidAPS Loop Control")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendLoopCommand() {
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.aapsQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            showAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                let success = try await AAPSRemoteService.shared.sendLoopCommand(action: selectedAction, otp: otpCode)
                await MainActor.run {
                    isLoading = false
                    if success {
                        alertType = .success
                        alertMessage = "Loop command sent successfully"
                    } else {
                        alertType = .error
                        alertMessage = "Failed to send loop command"
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
    AAPSLoopView()
}
