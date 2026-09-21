// LoopFollow
// LoopCarbEditSheet.swift

import HealthKit
import SwiftUI

/// Edit form for a carb entry already logged in Loop. Loop replaces the entry, keeping its sync identifier.
struct LoopCarbEditSheet: View {
    let carb: LoopCarbTreatment

    @Environment(\.presentationMode) private var presentationMode
    @State private var carbsAmount: HKQuantity
    @State private var absorptionHours: Int
    @State private var absorptionMinutes: Int
    @State private var foodType: String
    @State private var consumedDate: Date
    @State private var isSending = false
    @State private var alertType: AlertType?
    @FocusState private var carbsFocused: Bool

    private let maxPastHours = 12
    private let maxFutureHours = 1
    private let minAbsorptionHours = 0.5
    private let maxAbsorptionHours = 8

    private enum AlertType: Identifiable {
        case confirm
        case validation(String)
        case sendFailed(String)

        var id: String {
            switch self {
            case .confirm: return "confirm"
            case let .validation(message): return "validation-\(message)"
            case let .sendFailed(message): return "failed-\(message)"
            }
        }
    }

    init(carb: LoopCarbTreatment) {
        self.carb = carb
        _carbsAmount = State(initialValue: HKQuantity(unit: .gram(), doubleValue: carb.carbs))
        let totalMinutes = Int((carb.absorptionMinutes ?? 180).rounded())
        _absorptionHours = State(initialValue: totalMinutes / 60)
        _absorptionMinutes = State(initialValue: totalMinutes % 60 >= 30 ? 30 : 0)
        _foodType = State(initialValue: carb.foodType ?? "")
        _consumedDate = State(initialValue: Date(timeIntervalSince1970: carb.date))
    }

    private var absorptionTimeValue: Double {
        Double(absorptionHours) + Double(absorptionMinutes) / 60
    }

    private var dateRange: ClosedRange<Date> {
        let now = Date()
        let lower = min(now.addingTimeInterval(-TimeInterval(maxPastHours) * 3600), consumedDate)
        return lower ... now.addingTimeInterval(TimeInterval(maxFutureHours) * 3600)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current")) {
                    LabeledValueRow(label: "Carbs", value: String(format: "%.0f g", carb.carbs))
                    if let hours = carb.absorptionHours {
                        LabeledValueRow(label: "Absorption", value: String(format: "%.1f h", hours))
                    }
                    if let foodType = carb.foodType {
                        LabeledValueRow(label: "Food type", value: foodType)
                    }
                }

                Section(header: Text("New values"), footer: Text("Loop replaces the entry with these values and keeps its history.")) {
                    HKQuantityInputView(
                        label: "Carbs",
                        quantity: $carbsAmount,
                        unit: .gram(),
                        maxLength: 4,
                        minValue: HKQuantity(unit: .gram(), doubleValue: 1),
                        maxValue: Storage.shared.maxCarbs.value,
                        isFocused: $carbsFocused,
                        onValidationError: { alertType = .validation($0) }
                    )
                    HStack {
                        Text("Absorption")
                        Spacer()
                        Picker("Hours", selection: $absorptionHours) {
                            ForEach(0 ... maxAbsorptionHours, id: \.self) { Text("\($0) hr").tag($0) }
                        }
                        .labelsHidden()
                        Picker("Minutes", selection: $absorptionMinutes) {
                            ForEach([0, 30], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        .labelsHidden()
                    }
                    TextField("Food type (optional)", text: $foodType)
                    DatePicker("Time", selection: $consumedDate, in: dateRange, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, dateTimeUtils.displayTimeZone())
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    carbsFocused = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { validateAndConfirm() }
                } label: {
                    if isSending {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Sending...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Update Carbs").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSending)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Edit Carbs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(item: $alertType) { type in
                switch type {
                case .confirm:
                    return Alert(
                        title: Text("Update carbs in Loop?"),
                        message: Text(confirmationMessage),
                        primaryButton: .default(Text("Update"), action: send),
                        secondaryButton: .cancel()
                    )
                case let .validation(message):
                    return Alert(title: Text("Validation Error"), message: Text(message), dismissButton: .default(Text("OK")))
                case let .sendFailed(message):
                    return Alert(title: Text("Not Sent"), message: Text(message), dismissButton: .default(Text("OK")))
                }
            }
        }
    }

    private var confirmationMessage: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        dateTimeUtils.applyDisplayTimeZone(to: formatter)
        var lines = [
            String(format: "Carbs: %.0f g", carbsAmount.doubleValue(for: .gram())),
            String(format: "Absorption: %.1f h", absorptionTimeValue),
        ]
        if !foodType.isEmpty { lines.append("Food type: \(foodType)") }
        lines.append("Time: \(formatter.string(from: consumedDate))")
        return lines.joined(separator: "\n")
    }

    private func validateAndConfirm() {
        guard carbsAmount.doubleValue(for: .gram()) > 0 else {
            alertType = .validation("Enter a carb amount, or use Delete carbs to remove the entry.")
            return
        }
        guard absorptionTimeValue >= minAbsorptionHours, absorptionTimeValue <= Double(maxAbsorptionHours) else {
            alertType = .validation(String(format: "Please enter a valid absorption time between %.1f and %d hours", minAbsorptionHours, maxAbsorptionHours))
            return
        }
        alertType = .confirm
    }

    private func send() {
        isSending = true
        RemoteCommandTracker.shared.sendLoopCarbEdit(
            carb: carb,
            carbsAmount: carbsAmount.doubleValue(for: .gram()),
            absorptionHours: absorptionTimeValue,
            foodType: foodType.isEmpty ? nil : foodType,
            consumedDate: consumedDate
        ) { success, error in
            DispatchQueue.main.async {
                isSending = false
                if success {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    alertType = .sendFailed(error ?? "Failed to send the carb update.")
                }
            }
        }
    }
}
