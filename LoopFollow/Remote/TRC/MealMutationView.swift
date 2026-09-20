// LoopFollow
// MealMutationView.swift

import HealthKit
import SwiftUI

struct TRCMealEditView: View {
    let meal: TrioMealTreatment

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var coordinator = TRCMealMutationCoordinator.shared

    @State private var carbsText: String
    @State private var fatText: String
    @State private var proteinText: String
    @State private var mealTime: Date
    @State private var activeAlert: EditAlert?

    init(meal: TrioMealTreatment) {
        self.meal = meal
        _carbsText = State(initialValue: String(meal.carbs))
        _fatText = State(initialValue: String(meal.fat))
        _proteinText = State(initialValue: String(meal.protein))
        _mealTime = State(initialValue: Date(timeIntervalSince1970: meal.mealTime))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Meal") {
                    TRCMealMacroRows(
                        carbs: meal.carbs,
                        fat: meal.fat,
                        protein: meal.protein,
                        mealTime: meal.mealTime
                    )
                }

                Section("Replacement") {
                    integerField("Carbs", text: $carbsText)
                    integerField("Fat", text: $fatText)
                    integerField("Protein", text: $proteinText)

                    DatePicker(
                        "Meal Time",
                        selection: $mealTime,
                        in: mealTimeRange,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.timeZone, dateTimeUtils.displayTimeZone())
                }

                Section {
                    Button("Review Meal Update") {
                        reviewUpdate()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(coordinator.blockingOperation(forMealID: meal.mealID.uuidString) != nil)
                } footer: {
                    Text("Trio will independently verify the original meal values and its configured nutrient limits before applying this update.")
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .confirm:
                    return Alert(
                        title: Text("Confirm Meal Update"),
                        message: Text(confirmationMessage),
                        primaryButton: .default(Text("Send Update"), action: sendUpdate),
                        secondaryButton: .cancel()
                    )
                case let .error(message):
                    return Alert(
                        title: Text("Unable to Update Meal"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    private func integerField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text("g")
                .foregroundColor(.secondary)
        }
    }

    private var mealTimeRange: ClosedRange<Date> {
        let now = Date()
        let offset = TRCMealMutationTimePolicy.maximumOffset
        return now.addingTimeInterval(-offset) ... now.addingTimeInterval(offset)
    }

    private var replacement: TRCMealMutationValues? {
        guard let carbs = nonnegativeInteger(carbsText),
              let fat = nonnegativeInteger(fatText),
              let protein = nonnegativeInteger(proteinText)
        else {
            return nil
        }

        return TRCMealMutationValues(
            carbs: carbs,
            fat: fat,
            protein: protein,
            mealTime: mealTime.timeIntervalSince1970
        )
    }

    private var confirmationMessage: String {
        guard let replacement else { return "" }
        return """
        Current: C \(meal.carbs)g, F \(meal.fat)g, P \(meal.protein)g at \(formatMealTime(meal.mealTime))

        Replacement: C \(replacement.carbs)g, F \(replacement.fat)g, P \(replacement.protein)g at \(formatMealTime(replacement.mealTime))
        """
    }

    private func reviewUpdate() {
        if let error = validationError(at: Date()) {
            activeAlert = .error(error)
        } else {
            activeAlert = .confirm
        }
    }

    private func sendUpdate() {
        let now = Date()
        if let error = validationError(at: now) {
            activeAlert = .error(error)
            return
        }
        guard let replacement else {
            activeAlert = .error("Enter whole-number values for carbs, fat, and protein.")
            return
        }

        do {
            _ = try coordinator.startEdit(
                mealID: meal.mealID.uuidString,
                user: Storage.shared.user.value,
                expectedCarbs: meal.carbs,
                expectedFat: meal.fat,
                expectedProtein: meal.protein,
                expectedMealTime: meal.mealTime,
                carbs: replacement.carbs,
                fat: replacement.fat,
                protein: replacement.protein,
                scheduledTime: replacement.mealTime,
                at: now
            )
            dismiss()
        } catch {
            activeAlert = .error(error.localizedDescription)
        }
    }

    private func validationError(at now: Date) -> String? {
        if let error = TRCMealMutationUIValidation.sourceError(meal: meal, at: now) {
            return error
        }
        if let blocking = coordinator.blockingOperation(forMealID: meal.mealID.uuidString) {
            return "A previous meal request is still active: \(blocking.statusTitle)."
        }
        guard let replacement else {
            return "Enter whole-number values for carbs, fat, and protein."
        }
        guard replacement.hasValidMacros else {
            return "At least one nutrient must be greater than zero, and none can be negative."
        }
        if let error = TRCMealMutationUIValidation.timeError(replacement.mealTime, at: now, label: "Replacement time") {
            return error
        }

        let maxCarbs = Storage.shared.maxCarbs.value.doubleValue(for: .gram())
        let maxFat = Storage.shared.maxFat.value.doubleValue(for: .gram())
        let maxProtein = Storage.shared.maxProtein.value.doubleValue(for: .gram())
        guard Double(replacement.carbs) <= maxCarbs else {
            return "Carbs exceed LoopFollow’s configured maximum of \(Int(maxCarbs)) g. Trio will also enforce its own limit."
        }
        guard Double(replacement.fat) <= maxFat else {
            return "Fat exceeds LoopFollow’s configured maximum of \(Int(maxFat)) g. Trio will also enforce its own limit."
        }
        guard Double(replacement.protein) <= maxProtein else {
            return "Protein exceeds LoopFollow’s configured maximum of \(Int(maxProtein)) g. Trio will also enforce its own limit."
        }

        let original = TRCMealMutationValues(
            carbs: meal.carbs,
            fat: meal.fat,
            protein: meal.protein,
            mealTime: meal.mealTime
        )
        guard !original.matches(replacement) else {
            return "Change at least one nutrient or move the meal time by at least one minute."
        }
        return TRCMealMutationUIValidation.configurationError()
    }

    private func nonnegativeInteger(_ text: String) -> Int? {
        guard !text.isEmpty, let value = Int(text), value >= 0 else { return nil }
        return value
    }
}

struct TRCMealMacroRows: View {
    let carbs: Int
    let fat: Int
    let protein: Int
    let mealTime: TimeInterval

    var body: some View {
        valueRow("Carbs", value: "\(carbs) g")
        valueRow("Fat", value: "\(fat) g")
        valueRow("Protein", value: "\(protein) g")
        valueRow("Time", value: formatMealTime(mealTime))
    }

    private func valueRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct TRCMealMutationStatusSection: View {
    let operation: TRCMealMutationOperation
    let onError: (String) -> Void

    @ObservedObject private var coordinator = TRCMealMutationCoordinator.shared

    var body: some View {
        Section("Remote Meal Status") {
            Label(operation.statusTitle, systemImage: statusIcon)
                .foregroundColor(statusColor)
            Text(operation.statusDetail)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if operation.isRetryable {
                Button("Retry Same Request") {
                    do {
                        _ = try coordinator.retry(commandID: operation.commandID)
                    } catch {
                        onError(error.localizedDescription)
                    }
                }
            }
        }
        .task(id: timeoutTaskID) {
            guard operation.state == .sending || operation.state == .awaiting else { return }
            let elapsed = Date().timeIntervalSince(operation.lastAttemptAt)
            let remaining = max(0, TRCMealMutationCoordinator.attemptTimeout - elapsed)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            coordinator.markTimedOut(commandID: operation.commandID)
        }
    }

    private var timeoutTaskID: String {
        "\(operation.commandID)-\(operation.state.rawValue)-\(operation.lastAttemptAt.timeIntervalSince1970)"
    }

    private var statusIcon: String {
        switch operation.state {
        case .sending: return "arrow.up.circle"
        case .awaiting: return "clock"
        case .inProgress, .timedOut: return "hourglass"
        case .applied: return "checkmark.circle.fill"
        case .rejected, .transportFailed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch operation.state {
        case .applied: return .green
        case .rejected, .transportFailed: return .red
        case .sending, .awaiting, .inProgress, .timedOut: return .orange
        }
    }
}

enum TRCMealMutationUIValidation {
    static func staleSourceError(
        meal: TrioMealTreatment,
        after operation: TRCMealMutationOperation
    ) -> String? {
        guard operation.type == .edit,
              operation.state == .applied,
              operation.reconciledAt != nil,
              let replacement = operation.replacement
        else {
            return nil
        }

        let displayed = TRCMealMutationValues(
            carbs: meal.carbs,
            fat: meal.fat,
            protein: meal.protein,
            mealTime: meal.mealTime
        )
        guard !replacement.matches(displayed) else { return nil }
        return "This screen shows the previous meal values. Return to the treatment list and reopen the refreshed meal."
    }

    static func sourceError(meal: TrioMealTreatment, at now: Date) -> String? {
        if meal.isGeneratedFPU {
            return "This is a Trio-generated FPU entry. Edit or delete its root meal instead."
        }
        if let error = timeError(meal.mealTime, at: now, label: "Meal") {
            return error
        }
        guard meal.carbs >= 0,
              meal.fat >= 0,
              meal.protein >= 0,
              meal.carbs > 0 || meal.fat > 0 || meal.protein > 0
        else {
            return "This meal does not contain compatible whole-number nutrient values."
        }
        return nil
    }

    static func timeError(_ timestamp: TimeInterval, at now: Date, label: String) -> String? {
        guard !TRCMealMutationTimePolicy().isValid(timestamp, at: now) else { return nil }
        return "\(label) must be within 12 hours before or after now."
    }

    static func configurationError() -> String? {
        guard Storage.shared.remoteType.value == .trc, Storage.shared.device.value == "Trio" else {
            return "Meal editing requires Trio Remote Control with a Trio device."
        }
        guard !Storage.shared.user.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "The Trio Remote Control user is missing."
        }

        do {
            _ = try PushNotificationManager().requireReturnNotificationInfo()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

private enum EditAlert: Identifiable {
    case confirm
    case error(String)

    var id: String {
        switch self {
        case .confirm: return "confirm"
        case let .error(message): return "error-\(message)"
        }
    }
}

func formatMealTime(_ timestamp: TimeInterval) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    dateTimeUtils.applyDisplayTimeZone(to: formatter)
    return formatter.string(from: Date(timeIntervalSince1970: timestamp))
}
