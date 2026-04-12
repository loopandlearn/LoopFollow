// LoopFollow
// LoopAPNSCarbsView.swift

import HealthKit
import SwiftUI

struct LoopAPNSCarbsView: View {
    private typealias AbsorptionPreset = (hours: Int, minutes: Int)

    @Environment(\.presentationMode) var presentationMode
    @State private var carbsAmount = HKQuantity(unit: .gram(), doubleValue: 0.0)
    @State private var absorptionHours = 3
    @State private var absorptionMinutes = 0
    @State private var foodType = ""
    @State private var consumedDate = Date()
    @State private var showDatePickerSheet = false
    @State private var showAbsorptionPickerSheet = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .success
    @State private var otpTimeRemaining: Int? = nil
    @State private var showTOTPWarning = false
    private let otpPeriod: TimeInterval = 30
    private let timeAdjustmentStepMinutes = 5
    private let maxPastHours = 12
    private let maxFutureHours = 1
    private let minAllowedAbsorptionTime = 0.5
    private let maxAllowedAbsorptionTime = 8.0
    private let lollipopStandardAbsorption: AbsorptionPreset = (0, 30)
    private let tacoStandardAbsorption: AbsorptionPreset = (3, 0)
    private let pizzaStandardAbsorption: AbsorptionPreset = (5, 0)
    private var otpTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @FocusState private var carbsFieldIsFocused: Bool

    // Computed property to check if TOTP should be blocked
    private var isTOTPBlocked: Bool {
        TOTPService.shared.isTOTPBlocked(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
    }

    private var absorptionTimeValue: Double {
        Double(absorptionHours) + (Double(absorptionMinutes) / 60.0)
    }

    private var absorptionTimeText: String {
        if absorptionMinutes == 0 {
            return "\(absorptionHours) hr"
        }

        return "\(absorptionHours) hr \(absorptionMinutes) min"
    }

    private var absorptionConfirmationText: String {
        String(format: "%.1f", absorptionTimeValue)
    }

    private var minimumAbsorptionPreset: AbsorptionPreset {
        let minimumAbsorptionMinutes = Int(minAllowedAbsorptionTime * 60)
        return (minimumAbsorptionMinutes / 60, minimumAbsorptionMinutes % 60)
    }

    private var maximumAbsorptionHours: Int {
        Int(maxAllowedAbsorptionTime)
    }

    private var absorptionValidationMessage: String {
        String(
            format: "Please enter a valid absorption time between %.1f and %.1f hours",
            minAllowedAbsorptionTime,
            maxAllowedAbsorptionTime
        )
    }

    private var absorptionMinuteOptions: [Int] {
        if absorptionHours == minimumAbsorptionPreset.hours {
            return [minimumAbsorptionPreset.minutes]
        }

        if absorptionHours == maximumAbsorptionHours {
            return [0]
        }

        return [0, 30]
    }

    private var oldestAcceptedDate: Date {
        Date().addingTimeInterval(-TimeInterval(maxPastHours) * 60 * 60)
    }

    private var latestAcceptedDate: Date {
        Date().addingTimeInterval(TimeInterval(maxFutureHours) * 60 * 60)
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

                        HStack(spacing: 8) {
                            Text("Time")

                            Spacer()

                            Button(action: {
                                adjustConsumedDate(byMinutes: -timeAdjustmentStepMinutes)
                            }) {
                                Image(systemName: "minus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(.systemGray6))
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showDatePickerSheet = true
                            }) {
                                Text(consumedDate, format: Date.FormatStyle().hour().minute())
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.primary)
                                    .frame(minWidth: 58)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                adjustConsumedDate(byMinutes: timeAdjustmentStepMinutes)
                            }) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(.systemGray6))
                                    .frame(width: 28, height: 28)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(alignment: .center, spacing: 12) {
                            Text("Food Type")

                            Spacer()

                            HStack(spacing: 10) {
                                Button(action: {
                                    foodType = "🍭"
                                    setAbsorptionTime(hours: lollipopStandardAbsorption.hours, minutes: lollipopStandardAbsorption.minutes)
                                }) {
                                    Text("🍭")
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(foodType == "🍭" ? Color.white.opacity(0.12) : Color.clear)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    foodType = "🌮"
                                    setAbsorptionTime(hours: tacoStandardAbsorption.hours, minutes: tacoStandardAbsorption.minutes)
                                }) {
                                    Text("🌮")
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(foodType == "🌮" ? Color.white.opacity(0.12) : Color.clear)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    foodType = "🍕"
                                    setAbsorptionTime(hours: pizzaStandardAbsorption.hours, minutes: pizzaStandardAbsorption.minutes)
                                }) {
                                    Text("🍕")
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(foodType == "🍕" ? Color.white.opacity(0.12) : Color.clear)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    foodType = "🍽️"
                                    showAbsorptionPickerSheet = true
                                }) {
                                    Text("🍽️")
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(foodType == "🍽️" ? Color.white.opacity(0.12) : Color.clear)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 8) {
                            Text("Absorption Time")

                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.subheadline)

                            Spacer()

                            Button(action: {
                                showAbsorptionPickerSheet = true
                            }) {
                                Text(absorptionTimeText)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // TOTP Blocking Warning Section
                    if isTOTPBlocked && showTOTPWarning {
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
                .safeAreaInset(edge: .bottom) {
                    Button(action: sendCarbs) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Sending...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Send Carbs")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(carbsAmount.doubleValue(for: .gram()) <= 0 || isLoading || isTOTPBlocked)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
                .navigationTitle("Carbs")
                .navigationBarTitleDisplayMode(.inline)
            }
            .sheet(isPresented: $showDatePickerSheet) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Time",
                            selection: Binding(
                                get: { consumedDate },
                                set: { consumedDate = clampedConsumedDate($0) }
                            ),
                            in: oldestAcceptedDate ... latestAcceptedDate,
                            displayedComponents: [.hourAndMinute, .date]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()

                        Spacer()
                    }
                    .navigationTitle("Consumption Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                consumedDate = clampedConsumedDate(consumedDate)
                                showDatePickerSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAbsorptionPickerSheet) {
                NavigationStack {
                    VStack {
                        HStack(spacing: 0) {
                            Picker("Hours", selection: $absorptionHours) {
                                ForEach(0 ... maximumAbsorptionHours, id: \.self) { hour in
                                    Text("\(hour) hr")
                                        .tag(hour)
                                }
                            }

                            Picker("Minutes", selection: $absorptionMinutes) {
                                ForEach(absorptionMinuteOptions, id: \.self) { minute in
                                    Text("\(minute) min")
                                        .tag(minute)
                                }
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 180)
                        .padding(.horizontal)

                        Spacer()
                    }
                    .navigationTitle("Absorption Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                normalizeAbsorptionTime()
                                showAbsorptionPickerSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .onAppear {
                    normalizeAbsorptionTime()
                }
                .onChange(of: absorptionHours) { _ in
                    normalizeAbsorptionTime()
                }
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

                // Add delay before showing TOTP warning to prevent flash after successful send
                if isTOTPBlocked {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showTOTPWarning = true
                    }
                } else {
                    showTOTPWarning = false
                }
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
                        message: Text("Send \(Int(carbsAmount.doubleValue(for: .gram())))g of carbs with \(absorptionConfirmationText)h absorption time at \(timeFormatter.string(from: consumedDate))?"),
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

        let selectedAbsorptionTime = absorptionTimeValue
        guard selectedAbsorptionTime >= minAllowedAbsorptionTime, selectedAbsorptionTime <= maxAllowedAbsorptionTime else {
            alertMessage = absorptionValidationMessage
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
            absorptionTime: selectedAbsorptionTime,
            foodType: foodType.isEmpty ? nil : foodType,
            consumedDate: adjustedConsumedDate,
            otp: otpCode
        )

        let apnsService = LoopAPNSService()
        apnsService.sendCarbsViaAPNS(payload: payload) { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    // Mark TOTP code as used
                    TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                    let timeFormatter = DateFormatter()
                    timeFormatter.timeStyle = .short
                    self.alertMessage = "Carbs sent successfully for \(timeFormatter.string(from: adjustedConsumedDate))!"
                    self.alertType = .success
                    LogManager.shared.log(
                        category: .apns,
                        message: "Carbs sent - Amount: \(carbsAmount.doubleValue(for: .gram()))g, Absorption: \(absorptionConfirmationText)h, Time: \(adjustedConsumedDate)"
                    )
                } else {
                    self.alertMessage = errorMessage ?? "Failed to send carbs. Check your Loop APNS configuration."
                    self.alertType = .error
                    LogManager.shared.log(
                        category: .apns,
                        message: "Failed to send carbs: \(errorMessage ?? "unknown error")"
                    )
                }
                self.showAlert = true
            }
        }
    }

    private func setAbsorptionTime(hours: Int, minutes: Int) {
        absorptionHours = min(max(hours, 0), maximumAbsorptionHours)
        absorptionMinutes = minutes
        normalizeAbsorptionTime()
    }

    private func normalizeAbsorptionTime() {
        if absorptionTimeValue < minAllowedAbsorptionTime {
            absorptionHours = minimumAbsorptionPreset.hours
            absorptionMinutes = minimumAbsorptionPreset.minutes
            return
        }

        if absorptionTimeValue >= maxAllowedAbsorptionTime {
            absorptionHours = maximumAbsorptionHours
            absorptionMinutes = 0
            return
        }

        if !absorptionMinuteOptions.contains(absorptionMinutes) {
            absorptionMinutes = absorptionMinuteOptions.first ?? 0
        }
    }

    private func adjustConsumedDate(byMinutes minutes: Int) {
        let adjustedDate = Calendar.current.date(byAdding: .minute, value: minutes, to: consumedDate) ?? consumedDate
        consumedDate = clampedConsumedDate(adjustedDate)
    }

    private func clampedConsumedDate(_ date: Date) -> Date {
        min(max(date, oldestAcceptedDate), latestAcceptedDate)
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
