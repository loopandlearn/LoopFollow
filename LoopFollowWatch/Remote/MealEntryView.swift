// LoopFollow
// MealEntryView.swift

import SwiftUI

/// Carbs for Loop; carbs, fat, protein and an optional bolus for Trio, following
/// the phone's Meal settings. Everything goes to the phone as one command.
struct MealEntryView: View {
    let remote: WatchRemoteConfig

    @Environment(\.dismiss) private var dismiss
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var protein = 0.0
    @State private var bolus = 0.0
    @State private var offsetMinutes = 0.0
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case carbs, fat, protein, bolus, time
    }

    private var bolusStep: Double { max(remote.bolusIncrement, 0.025) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                field("Carbs", .carbs) {
                    AmountField(value: $carbs, unit: "g", step: 1, maximum: remote.maxCarbs, isHighlighted: focus == .carbs, format: grams)
                }
                if remote.mealWithFatProtein {
                    field("Fat", .fat) {
                        AmountField(value: $fat, unit: "g", step: 1, maximum: remote.maxFat, isHighlighted: focus == .fat, format: grams)
                    }
                    field("Protein", .protein) {
                        AmountField(value: $protein, unit: "g", step: 1, maximum: remote.maxProtein, isHighlighted: focus == .protein, format: grams)
                    }
                }
                if remote.mealWithBolus {
                    field("Bolus", .bolus) {
                        AmountField(value: $bolus, unit: "U", step: bolusStep, maximum: remote.maxBolus, isHighlighted: focus == .bolus, format: WatchFormat.insulin)
                    }
                }
                field("Time", .time) {
                    AmountField(value: $offsetMinutes, unit: "min", step: 5, minimum: -120, maximum: 60, isHighlighted: focus == .time, format: timeText)
                }

                NavigationLink {
                    CommandConfirmView(
                        title: "Meal",
                        lines: summaryLines,
                        action: .meal(carbs: carbs, fat: fat, protein: protein, bolus: bolus, consumedAt: Date().addingTimeInterval(offsetMinutes * 60)),
                        deliversInsulin: bolus > 0,
                        onSuccess: { dismiss() }
                    )
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(carbs <= 0 && fat <= 0 && protein <= 0)
            }
        }
        .navigationTitle("Meal")
        .onAppear { focus = .carbs }
    }

    private func field(_ label: String, _ id: Field, content: () -> AmountField) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content()
                .focused($focus, equals: id)
        }
    }

    private func grams(_ value: Double) -> String {
        "\(Int(value))"
    }

    private func timeText(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m == 0 { return "Now" }
        return m > 0 ? "+\(m)" : "\(m)"
    }

    private var summaryLines: [String] {
        var lines: [String] = []
        if carbs > 0 { lines.append("Carbs \(Int(carbs)) g") }
        if fat > 0 { lines.append("Fat \(Int(fat)) g") }
        if protein > 0 { lines.append("Protein \(Int(protein)) g") }
        if bolus > 0 { lines.append("Bolus \(WatchFormat.insulin(bolus)) U") }
        let at = Date().addingTimeInterval(offsetMinutes * 60)
        lines.append(offsetMinutes == 0 ? "Now" : at.formatted(date: .omitted, time: .shortened))
        return lines
    }
}
