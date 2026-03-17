// LoopFollow
// AAPSStatusView.swift

import SwiftUI

struct AAPSStatusView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success

    enum AlertType {
        case success
        case error
    }

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

                VStack(spacing: 16) {
                    Button(action: {
                        sendStatusCommand()
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.title2)
                            Text("Get System Status")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !AAPSRemoteService.shared.validateSetup())

                    if isLoading {
                        ProgressView("Getting status...")
                            .padding()
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("AndroidAPS Status")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendStatusCommand() {
        isLoading = true

        Task {
            do {
                let success = try await AAPSRemoteService.shared.sendStatusCommand()
                await MainActor.run {
                    isLoading = false
                    if success {
                        alertType = .success
                        alertMessage = "Status command sent successfully"
                    } else {
                        alertType = .error
                        alertMessage = "Failed to send status command"
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
    AAPSStatusView()
}
