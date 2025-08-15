// LoopFollow
// LoopAPNSCarbsView.swift

import HealthKit
import SwiftUI

struct LoopAPNSCarbsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var carbsAmount = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var absorptionTimeString = "3.0"
    @State private var foodType = ""
    @State private var consumedDate = Date()
    @State private var showDatePickerSheet = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var otpTimeRemaining: Int? = nil
    private let otpPeriod: TimeInterval = 30
    private var otpTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @FocusState private var carbsFieldIsFocused: Bool
    @FocusState private var absorptionFieldIsFocused: Bool

    // Computed property to check if TOTP should be blocked
    private var isTOTPBlocked: Bool {
        TOTPService.shared.isTOTPBlocked(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
    }

    enum AlertType {
        case success
        case error
        case confirmation
    }

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section {
                        HKQuantityInputView(
                            label: "Carbs Amount",
                            quantity: $carbsAmount,
                            unit: .gram(),
                            maxLength: 4,
                            minValue: HKQuantity(unit: .gram(), doubleValue: 1.0),
                            maxValue: Storage.shared.maxCarbs.value,
                            isFocused: $carbsFieldIsFocused,
                            onValidationError: { message in
                                alertMessage = message
                                alertType = .error
                                showAlert = true
                            }
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Food Type")
                                .font(.headline)

                            HStack(spacing: 12) {
                                // Fast carb entry emoji (0.5 hours)
                                Button(action: {
                                    foodType = "🍭"
                                    absorptionTimeString = "0.5"
                                }) {
                                    Text("🍭")
                                        .font(.title)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Medium carb entry emoji (3 hours)
                                Button(action: {
                                    foodType = "🌮"
                                    absorptionTimeString = "3.0"
                                }) {
                                    Text("🌮")
                                        .font(.title)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Slow carb entry emoji (5 hours)
                                Button(action: {
                                    foodType = "🍕"
                                    absorptionTimeString = "5.0"
                                }) {
                                    Text("🍕")
                                        .font(.title)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Custom carb entry emoji (clears and focuses absorption)
                                Button(action: {
                                    foodType = "🍽️"
                                    absorptionTimeString = ""
                                    absorptionFieldIsFocused = true
                                }) {
                                    Text("🍽️")
                                        .font(.title)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Spacer()
                            }
                        }

                        HStack {
                            Text("Absorption Time")
                            Spacer()
                            TextField("0.0", text: $absorptionTimeString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($absorptionFieldIsFocused)
                                .onChange(of: absorptionTimeString) { newValue in
                                    // Only allow numbers and decimal point
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    // Ensure only one decimal point
                                    let components = filtered.components(separatedBy: ".")
                                    if components.count > 2 {
                                        absorptionTimeString = String(filtered.dropLast())
                                    } else {
                                        absorptionTimeString = filtered
                                    }
                                }
                            Text("hr")
                                .foregroundColor(.secondary)
                        }

                        // Time input section
                        VStack(alignment: .leading) {
                            Text("Time")
                                .font(.headline)

                            Button(action: {
                                showDatePickerSheet = true
                            }) {
                                HStack {
                                    Text(consumedDate, format: Date.FormatStyle().hour().minute())
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    Section {
                        Button(action: sendCarbs) {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Sending...")
                                }
                            } else {
                                Text("Send Carbs")
                            }
                        }
                        .disabled(carbsAmount.doubleValue(for: .gram()) <= 0 || isLoading || isTOTPBlocked)
                        .frame(maxWidth: .infinity)
                    }

                    // TOTP Blocking Warning Section
                    if isTOTPBlocked {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("TOTP Code Already Used")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                Text("This TOTP code has already been used for a command. Please wait for the next code to be generated before sending another command.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section(header: Text("Security")) {
                        VStack(alignment: .leading) {
                            Text("Current OTP Code")
                                .font(.headline)
                            if let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value) {
                                HStack {
                                    Text(otpCode)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.green)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                    Text("(" + (otpTimeRemaining.map { "\($0)s left" } ?? "-") + ")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Invalid QR code URL")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .navigationTitle("Carbs")
                .navigationBarTitleDisplayMode(.inline)
            }
            .sheet(isPresented: $showDatePickerSheet) {
                VStack {
                    Text("Consumption Time")
                        .font(.headline)
                        .padding()
                    Form {
                        DatePicker("Time", selection: $consumedDate, displayedComponents: [.hourAndMinute, .date])
                            .datePickerStyle(.automatic)
                    }
                }
                .presentationDetents([.fraction(1 / 4)])
            }
            .onAppear {
                // Validate APNS setup
                let apnsService = LoopAPNSService()
                if !apnsService.validateSetup() {
                    alertMessage = "Loop APNS setup is incomplete. Please configure all required fields in settings."
                    alertType = .error
                    showAlert = true
                }
                // Reset timer state so it shows '-' until first tick
                otpTimeRemaining = nil
                // Don't reset TOTP usage flag here - let the timer handle it

                // Validate TOTP state when view appears
                _ = isTOTPBlocked
            }
            .onReceive(otpTimer) { _ in
                let now = Date().timeIntervalSince1970
                let newOtpTimeRemaining = Int(otpPeriod - (now.truncatingRemainder(dividingBy: otpPeriod)))

                // Check if we've moved to a new TOTP period (when time remaining increases)
                if let currentOtpTimeRemaining = otpTimeRemaining,
                   newOtpTimeRemaining > currentOtpTimeRemaining
                {
                    // New TOTP code generated, reset the usage flag
                    TOTPService.shared.resetTOTPUsage()
                }

                // Also check if we're at the very beginning of a new period (when time remaining is close to 30)
                if newOtpTimeRemaining >= 29 {
                    // We're at the start of a new TOTP period, reset the usage flag
                    TOTPService.shared.resetTOTPUsage()
                }

                otpTimeRemaining = newOtpTimeRemaining
            }
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .success:
                    return Alert(
                        title: Text("Success"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                case .error:
                    return Alert(
                        title: Text("Error"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                case .confirmation:
                    let timeFormatter = DateFormatter()
                    timeFormatter.timeStyle = .short
                    timeFormatter.dateStyle = .short
                    return Alert(
                        title: Text("Confirm Carbs"),
                        message: Text("Send \(Int(carbsAmount.doubleValue(for: .gram())))g of carbs with \(absorptionTimeString)h absorption time at \(timeFormatter.string(from: consumedDate))?"),
                        primaryButton: .default(Text("Send")) {
                            sendCarbsConfirmed()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }

    private func sendCarbs() {
        guard carbsAmount.doubleValue(for: .gram()) > 0 else {
            alertMessage = "Please enter a valid carb amount"
            alertType = .error
            showAlert = true
            return
        }

        // Check guardrails
        let maxCarbs = Storage.shared.maxCarbs.value.doubleValue(for: .gram())
        let carbsValue = carbsAmount.doubleValue(for: .gram())

        if carbsValue > maxCarbs {
            alertMessage = "Carbs amount (\(Int(carbsValue))g) exceeds the maximum allowed (\(Int(maxCarbs))g). Please reduce the amount."
            alertType = .error
            showAlert = true
            return
        }

        // Validate time constraints (similar to LoopCaregiver)
        let now = Date()
        let maxPastHours = 12
        let maxFutureHours = 1
        let oldestAcceptedDate = now.addingTimeInterval(-60 * 60 * Double(maxPastHours))
        let latestAcceptedDate = now.addingTimeInterval(60 * 60 * Double(maxFutureHours))

        if consumedDate < oldestAcceptedDate {
            alertMessage = "Time must be within the prior \(maxPastHours) hours"
            alertType = .error
            showAlert = true
            return
        }

        if consumedDate > latestAcceptedDate {
            alertMessage = "Time must be within the next \(maxFutureHours) hour"
            alertType = .error
            showAlert = true
            return
        }

        alertType = .confirmation
        showAlert = true
    }

    private func sendCarbsConfirmed() {
        isLoading = true

        // Extract OTP from QR code URL
        guard let otpCode = TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value) else {
            alertMessage = "Invalid QR code URL. Please re-scan the QR code in settings."
            alertType = .error
            isLoading = false
            showAlert = true
            return
        }

        // Parse absorption time string to double
        guard let absorptionTimeValue = Double(absorptionTimeString), absorptionTimeValue >= 0.5, absorptionTimeValue <= 8.0 else {
            alertMessage = "Please enter a valid absorption time between 0.5 and 8.0 hours"
            alertType = .error
            isLoading = false
            showAlert = true
            return
        }

        // Create the APNS payload for carbs with custom time
        // We "randomize" the milliseconds to avoid issue with NS which
        // doesn't allow entries at the same second.
        let adjustedConsumedDate = consumedDate.dateUsingCurrentSeconds()
        let payload = LoopAPNSPayload(
            type: .carbs,
            carbsAmount: carbsAmount.doubleValue(for: .gram()),
            absorptionTime: absorptionTimeValue,
            foodType: foodType.isEmpty ? nil : foodType,
            consumedDate: adjustedConsumedDate,
            otp: otpCode
        )

        Task {
            do {
                let apnsService = LoopAPNSService()
                let success = try await apnsService.sendCarbsViaAPNS(payload: payload)

                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        // Mark TOTP code as used
                        TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                        let timeFormatter = DateFormatter()
                        timeFormatter.timeStyle = .short
                        alertMessage = "Carbs sent successfully for \(timeFormatter.string(from: adjustedConsumedDate))!"
                        alertType = .success
                        LogManager.shared.log(
                            category: .apns,
                            message: "Carbs sent - Amount: \(carbsAmount.doubleValue(for: .gram()))g, Absorption: \(absorptionTimeString)h, Time: \(adjustedConsumedDate)"
                        )
                    } else {
                        alertMessage = "Failed to send carbs. Check your Loop APNS configuration."
                        alertType = .error
                        LogManager.shared.log(
                            category: .apns,
                            message: "Failed to send carbs"
                        )
                    }
                    showAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    alertMessage = "Error sending carbs: \(error.localizedDescription)"
                    alertType = .error
                    LogManager.shared.log(
                        category: .apns,
                        message: "APNS carbs error: \(error.localizedDescription)"
                    )
                    showAlert = true
                }
            }
        }
    }
}

// APNS Payload structure for carbs
struct LoopAPNSPayload {
    enum PayloadType {
        case carbs
        case bolus
    }

    let type: PayloadType
    let carbsAmount: Double?
    let absorptionTime: Double?
    let foodType: String?
    let bolusAmount: Double?
    let consumedDate: Date?
    let otp: String

    init(type: PayloadType, carbsAmount: Double? = nil, absorptionTime: Double? = nil, foodType: String? = nil, bolusAmount: Double? = nil, consumedDate: Date? = nil, otp: String) {
        self.type = type
        self.carbsAmount = carbsAmount
        self.absorptionTime = absorptionTime
        self.foodType = foodType
        self.bolusAmount = bolusAmount
        self.consumedDate = consumedDate
        self.otp = otp
    }
}
