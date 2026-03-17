// LoopFollow
// AAPSTargetView.swift

import SwiftUI

struct AAPSTargetView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var selectedTargetType = "MEAL"

    enum AlertType {
        case success
        case error
    }

    private let targetTypes = [
        ("MEAL", "Meal Target"),
        ("ACTIVITY", "Activity Target"),
        ("HYPO", "Hypo Target"),
        ("STOP", "Cancel Target"),
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
                    Section(header: Text("Target Type")) {
                        Picker("Target Type", selection: $selectedTargetType) {
                            ForEach(targetTypes, id: \.0) { type, label in
                                Text(label).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section {
                        Button(action: {
                            sendTargetCommand()
                        }) {
                            HStack {
                                Image(systemName: "target")
                                    .font(.title2)
                                Text("Step 1: Send Target Command")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!AAPSRemoteService.shared.validateSetup())

                        Button(action: {
                            sendOTPCode()
                        }) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .font(.title2)
                                Text("Step 2: Send OTP Code")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!AAPSRemoteService.shared.validateSetup())
                    }
                }
                .navigationBarTitle("Target Command", displayMode: .inline)

                if isLoading {
                    ProgressView("Sending target command...")
                        .padding()
                }
            }
            .navigationTitle("AndroidAPS Target")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendTargetCommand() {
        let aapsPhoneNumber = Storage.shared.aapsPhoneNumber.value
        let command = "TARGET \(selectedTargetType.uppercased())"

        // Open Messages app with the target command
        let success = AAPSRemoteService.shared.openMessagesApp(with: aapsPhoneNumber, message: command)

        if success {
            alertType = .success
            alertMessage = "Messages app opened with target command. Send the message, then use Step 2 to send the OTP code."
        } else {
            alertType = .error
            alertMessage = "Failed to open Messages app"
        }
        showAlert = true
    }

    private func sendOTPCode() {
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.aapsQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            showAlert = true
            return
        }

        let aapsPhoneNumber = Storage.shared.aapsPhoneNumber.value
        let success = AAPSRemoteService.shared.openMessagesApp(with: aapsPhoneNumber, message: otpCode)

        if success {
            alertType = .success
            alertMessage = "Messages app opened with OTP code. Send this message to complete the command."
        } else {
            alertType = .error
            alertMessage = "Failed to open Messages app for OTP"
        }
        showAlert = true
    }
}

#Preview {
    AAPSTargetView()
}
