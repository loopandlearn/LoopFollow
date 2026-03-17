// LoopFollow
// AAPSPumpView.swift

import SwiftUI

struct AAPSPumpView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var selectedAction = "CONNECT"

    enum AlertType {
        case success
        case error
    }

    private let pumpActions = [
        ("CONNECT", "Connect Pump"),
        ("DISCONNECT", "Disconnect Pump"),
        ("STATUS", "Pump Status"),
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
                    Section(header: Text("Pump Action")) {
                        Picker("Pump Action", selection: $selectedAction) {
                            ForEach(pumpActions, id: \.0) { action, label in
                                Text(label).tag(action)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section {
                        Button(action: {
                            sendPumpCommand()
                        }) {
                            HStack {
                                Image(systemName: "pump.medical")
                                    .font(.title2)
                                Text("Send Pump Command")
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
                    ProgressView("Sending pump command...")
                        .padding()
                }
            }
            .navigationTitle("AndroidAPS Pump Control")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendPumpCommand() {
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.aapsQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            showAlert = true
            return
        }

        isLoading = true

        Task {
            do {
                let success = try await AAPSRemoteService.shared.sendPumpCommand(action: selectedAction, otp: otpCode)
                await MainActor.run {
                    isLoading = false
                    if success {
                        alertType = .success
                        alertMessage = "Pump command sent successfully"
                    } else {
                        alertType = .error
                        alertMessage = "Failed to send pump command"
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
    AAPSPumpView()
}
