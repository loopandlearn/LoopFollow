// LoopFollow
// AAPSCarbsView.swift

import HealthKit
import SwiftUI

struct AAPSCarbsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var carbsAmount = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var timeString = ""

    @FocusState private var carbsFieldIsFocused: Bool

    enum AlertType {
        case success
        case error
        case confirmation
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

                Form {
                    Section {
                        HKQuantityInputView(
                            label: "Carbs Amount",
                            quantity: $carbsAmount,
                            unit: .gram(),
                            maxLength: 5,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 0.1),
                            maxValue: Storage.shared.maxCarbs.value,
                            isFocused: $carbsFieldIsFocused,
                            onValidationError: { message in
                                alertMessage = message
                                alertType = .error
                                showAlert = true
                            }
                        )
                    }

                    Section {
                        HStack {
                            Text("Time (optional)")
                            TextField("14:30 or 2:30PM", text: $timeString)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }

                    Section {
                        Button(action: {
                            sendCarbsCommand()
                        }) {
                            HStack {
                                Image(systemName: "fork.knife")
                                    .font(.title2)
                                Text("Step 1: Send Carbs Command")
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
                .navigationBarTitle("Carbs Command", displayMode: .inline)

                if isLoading {
                    ProgressView("Sending carbs command...")
                        .padding()
                }
            }
            .navigationTitle("AndroidAPS Carbs")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendCarbsCommand() {
        let aapsPhoneNumber = Storage.shared.aapsPhoneNumber.value
        let amount = carbsAmount.doubleValue(for: .gram())
        var command = "CARBS \(Int(amount))"
        if !timeString.isEmpty {
            command += " \(timeString)"
        }

        // Open Messages app with the carbs command
        let success = AAPSRemoteService.shared.openMessagesApp(with: aapsPhoneNumber, message: command)

        if success {
            alertType = .success
            alertMessage = "Messages app opened with carbs command. Send the message, then use Step 2 to send the OTP code."
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
    AAPSCarbsView()
}
