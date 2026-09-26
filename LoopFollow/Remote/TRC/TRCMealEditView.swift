// LoopFollow
// TRCMealEditView.swift

import HealthKit
import SwiftUI

/// Edit form for a meal already logged in Trio. Trio replaces the meal with these values.
struct TRCMealEditView: View {
    let meal: TrioMealTreatment

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var mealWithFatProtein = Storage.shared.mealWithFatProtein

    @State private var carbs: HKQuantity
    @State private var fat: HKQuantity
    @State private var protein: HKQuantity
    @State private var mealDate: Date
    @State private var isSending = false
    @State private var alertType: AlertType?

    @FocusState private var carbsFocused: Bool
    @FocusState private var fatFocused: Bool
    @FocusState private var proteinFocused: Bool

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

    init(meal: TrioMealTreatment) {
        self.meal = meal
        _carbs = State(initialValue: HKQuantity(unit: .gram(), doubleValue: Double(meal.carbsForEdit)))
        _fat = State(initialValue: HKQuantity(unit: .gram(), doubleValue: Double(meal.fat)))
        _protein = State(initialValue: HKQuantity(unit: .gram(), doubleValue: Double(meal.protein)))
        _mealDate = State(initialValue: Date(timeIntervalSince1970: meal.date))
    }

    private var showFatProtein: Bool {
        mealWithFatProtein.value || meal.fat > 0 || meal.protein > 0
    }

    private var dateRange: ClosedRange<Date> {
        let now = Date()
        return now.addingTimeInterval(-TrioMealTreatment.pastEditWindow) ... now.addingTimeInterval(TrioMealTreatment.futureEditWindow)
    }

    private var carbsValue: Int { Int(carbs.doubleValue(for: .gram()).rounded()) }
    private var fatValue: Int { showFatProtein ? Int(fat.doubleValue(for: .gram()).rounded()) : 0 }
    private var proteinValue: Int { showFatProtein ? Int(protein.doubleValue(for: .gram()).rounded()) : 0 }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current")) {
                    TRCMealMacroRows(carbs: meal.carbs, fat: meal.fat, protein: meal.protein, date: meal.date)
                }

                Section(header: Text("New values"), footer: Text("Trio replaces the meal, including any fat and protein entries, with these values.")) {
                    MealMacroInputs(
                        carbs: $carbs,
                        fat: $fat,
                        protein: $protein,
                        showFatProtein: showFatProtein,
                        carbsFocused: $carbsFocused,
                        fatFocused: $fatFocused,
                        proteinFocused: $proteinFocused,
                        onValidationError: { alertType = .validation($0) },
                        currentValues: (
                            HKQuantity(unit: .gram(), doubleValue: meal.carbs),
                            HKQuantity(unit: .gram(), doubleValue: Double(meal.fat)),
                            HKQuantity(unit: .gram(), doubleValue: Double(meal.protein))
                        )
                    )
                    DatePicker("Meal time", selection: $mealDate, in: dateRange, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, dateTimeUtils.displayTimeZone())
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    carbsFocused = false
                    fatFocused = false
                    proteinFocused = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        guard carbsValue > 0 || fatValue > 0 || proteinValue > 0 else {
                            alertType = .validation("Enter at least one of carbs, fat, or protein. Use Delete meal to remove the meal.")
                            return
                        }
                        alertType = .confirm
                    }
                } label: {
                    if isSending {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Sending...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Update Meal").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSending)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Edit Meal")
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
                        title: Text("Update meal in Trio?"),
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
        var lines = ["Carbs: \(carbsValue) g"]
        if showFatProtein {
            lines.append("Fat: \(fatValue) g")
            lines.append("Protein: \(proteinValue) g")
        }
        lines.append("Time: \(formatter.string(from: mealDate))")
        return lines.joined(separator: "\n")
    }

    private func send() {
        isSending = true
        RemoteCommandTracker.shared.sendTrioMealEdit(
            mealID: meal.mealID.uuidString,
            carbs: carbsValue,
            fat: fatValue,
            protein: proteinValue,
            date: mealDate
        ) { success, error in
            DispatchQueue.main.async {
                isSending = false
                if success {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    alertType = .sendFailed(error ?? "Failed to send the meal update.")
                }
            }
        }
    }
}

/// Read-only macro rows shared by the edit form and the treatment detail view.
struct TRCMealMacroRows: View {
    let carbs: Double
    let fat: Int
    let protein: Int
    let date: TimeInterval

    var body: some View {
        LabeledValueRow(label: "Carbs", value: carbs == carbs.rounded() ? String(format: "%.0f g", carbs) : String(format: "%.1f g", carbs))
        if fat > 0 { LabeledValueRow(label: "Fat", value: "\(fat) g") }
        if protein > 0 { LabeledValueRow(label: "Protein", value: "\(protein) g") }
        LabeledValueRow(label: "Time", value: formattedTime)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateTimeUtils.applyDisplayTimeZone(to: formatter)
        return formatter.string(from: Date(timeIntervalSince1970: date))
    }
}
