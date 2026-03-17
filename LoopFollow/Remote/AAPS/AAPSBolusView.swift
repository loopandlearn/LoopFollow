// LoopFollow
// AAPSBolusView.swift

import HealthKit
import SwiftUI

struct AAPSBolusView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var insulinAmount = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    @State private var isMeal = false
    @State private var showAlert = false
    @State private var alertType: AlertType = .success
    @State private var alertMessage = ""
    @State private var isLoading = false

    @FocusState private var insulinFieldIsFocused: Bool

    enum AlertType {
        case success
        case error
        case confirmation
    }

    var body: some View {
        NavigationView {
            Form {
                // OTP Display
                Section {
                    HStack {
                        Text("Current OTP:")
                        Spacer()
                        if let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.aapsQrCodeURL.value) {
                            Text(otpCode)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                        } else {
                            Text("Invalid QR Code")
                                .foregroundColor(.red)
                        }
                    }
                }

                // Insulin Amount Input
                Section(header: Text("Insulin Amount")) {
                    HKQuantityInputView(
                        label: "Insulin Amount",
                        quantity: $insulinAmount,
                        unit: .internationalUnit(),
                        maxLength: 5,
                        minValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.025),
                        maxValue: Storage.shared.maxBolus.value,
                        isFocused: $insulinFieldIsFocused,
                        onValidationError: { message in
                            alertMessage = message
                            alertType = .error
                            showAlert = true
                        }
                    )
                }

                // Meal Bolus Toggle
                Section {
                    Toggle("Meal Bolus", isOn: $isMeal)
                }

                // Action Buttons
                Section {
                    Button(action: {
                        sendBolusCommand()
                    }) {
                        HStack {
                            Image(systemName: "syringe")
                                .font(.title2)
                            Text("Step 1: Send Bolus Command")
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
            .navigationBarTitle("Bolus Command", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .alert(alertType == .success ? "Success" : "Error", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func sendBolusCommand() {
        let phoneNumber = Storage.shared.aapsPhoneNumber.value
        let amount = insulinAmount.doubleValue(for: .internationalUnit())
        let command = isMeal ? "BOLUS \(String(format: "%.2f", amount)) MEAL" : "BOLUS \(String(format: "%.2f", amount))"

        // Open Messages app with the bolus command
        let success = AAPSRemoteService.shared.openMessagesApp(with: phoneNumber, message: command)

        if success {
            alertType = .success
            alertMessage = "Messages app opened with bolus command. Send the message, then use Step 2 to send the OTP code."
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
    AAPSBolusView()
}
