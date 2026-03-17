// LoopFollow
// AAPSBGView.swift

import SwiftUI

struct AAPSBGView: View {
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

                // BG Status Button
                Button(action: {
                    sendBGStatusCommand()
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                        Text("Open Messages with BG Command")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!AAPSRemoteService.shared.validateSetup())

                Spacer()
            }
            .padding()
            .navigationTitle("BG Status")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendBGStatusCommand() {
        let phoneNumber = Storage.shared.aapsPhoneNumber.value
        let command = "BG"

        let success = AAPSRemoteService.shared.openMessagesApp(with: phoneNumber, message: command)

        if success {
            alertType = .success
            alertMessage = "Opening Messages app with BG command"
        } else {
            alertType = .error
            alertMessage = "Failed to open Messages app"
        }
        showAlert = true
    }
}

#Preview {
    AAPSBGView()
}
