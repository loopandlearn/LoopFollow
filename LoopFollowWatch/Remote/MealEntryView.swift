// LoopFollow
// MealEntryView.swift

import SwiftUI

/// Carbs, and for Trio fat, protein and a bolus per the phone's Meal settings,
/// as on the phone; the time behind a button. Everything goes as one command.
/// The crown scrolls the page until a field is tapped.
struct MealEntryView: View {
    let remote: WatchRemoteConfig

    @EnvironmentObject private var navigator: WatchNavigator
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var protein = 0.0
    @State private var bolus = 0.0
    @State private var offsetMinutes = 0.0
    @State private var showTime = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case carbs, fat, protein, bolus, time
    }

    private var bolusStep: Double { BolusAmountView.step(remote) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                quickPicks

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
                        AmountField(value: $bolus, unit: "U", step: bolusStep, maximum: remote.maxBolus, isHighlighted: focus == .bolus, sensitivity: .low, format: WatchFormat.insulin)
                    }
                }
                if showTime {
                    field("Time", .time) {
                        AmountField(value: $offsetMinutes, unit: "min", step: 5, minimum: -120, maximum: 60, isHighlighted: focus == .time, format: timeText)
                    }
                } else {
                    Button {
                        showTime = true
                        focus = .time
                    } label: {
                        Label("Time", systemImage: "clock")
                            .font(.footnote)
                    }
                    .buttonStyle(CompactButtonStyle())
                }

                Button {
                    navigator.push(.confirm(request(carbs: carbs, fat: fat, protein: protein, bolus: bolus, offsetMinutes: offsetMinutes)))
                } label: {
                    Text(logTitle)
                }
                .buttonStyle(CompactButtonStyle(prominent: true))
                .tint(.blue)
                .disabled(carbs <= 0 && fat <= 0 && protein <= 0)
            }
        }
        .navigationTitle("Meal")
    }

    /// The phone's Quick-Pick meals, limited to what the phone's Meal settings allow.
    @ViewBuilder
    private var quickPicks: some View {
        let picks = remote.quickPickMeals.filter { $0.carbs > 0 && $0.carbs <= remote.maxCarbs }
        if !picks.isEmpty {
            ForEach(Array(picks.enumerated()), id: \.offset) { _, pick in
                let fat = remote.mealWithFatProtein ? pick.fat : 0
                let protein = remote.mealWithFatProtein ? pick.protein : 0
                let bolus = remote.mealWithBolus && pick.bolus <= remote.maxBolus ? pick.bolus : 0
                Button {
                    navigator.push(.confirm(request(carbs: pick.carbs, fat: fat, protein: protein, bolus: bolus, offsetMinutes: 0)))
                } label: {
                    Text(pickTitle(carbs: pick.carbs, fat: fat, protein: protein, bolus: bolus))
                }
                .buttonStyle(CompactButtonStyle())
            }
        }
    }

    private func field(_ label: String, _ id: Field, content: () -> AmountField) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            content()
                .focused($focus, equals: id)
                .onTapGesture { focus = id }
        }
    }

    private var logTitle: String {
        if bolus > 0 { return "Log \(Int(carbs)) g + \(WatchFormat.insulin(bolus)) U" }
        return "Log \(Int(carbs)) g"
    }

    private func pickTitle(carbs: Double, fat: Double, protein: Double, bolus: Double) -> String {
        var parts = ["\(Int(carbs)) g"]
        if fat > 0 || protein > 0 { parts.append("F \(Int(fat)) P \(Int(protein))") }
        if bolus > 0 { parts.append("\(WatchFormat.insulin(bolus)) U") }
        return parts.joined(separator: " · ")
    }

    private func grams(_ value: Double) -> String {
        "\(Int(value))"
    }

    private func timeText(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m == 0 { return "Now" }
        return m > 0 ? "+\(m)" : "\(m)"
    }

    private func request(carbs: Double, fat: Double, protein: Double, bolus: Double, offsetMinutes: Double) -> CommandRequest {
        var lines: [String] = []
        if carbs > 0 { lines.append("Carbs \(Int(carbs)) g") }
        if fat > 0 { lines.append("Fat \(Int(fat)) g") }
        if protein > 0 { lines.append("Protein \(Int(protein)) g") }
        if bolus > 0 { lines.append("Bolus \(WatchFormat.insulin(bolus)) U") }
        let at = Date().addingTimeInterval(offsetMinutes * 60)
        lines.append(offsetMinutes == 0 ? "Now" : at.formatted(date: .omitted, time: .shortened))
        if bolus > 0, offsetMinutes != 0 {
            // Same note as the phone's meal screen.
            lines.append("The meal will be scheduled, but the bolus is enacted immediately.")
        }
        return CommandRequest(
            title: "Meal",
            lines: lines,
            action: .meal(carbs: carbs, fat: fat, protein: protein, bolus: bolus, consumedAt: at),
            deliversInsulin: bolus > 0
        )
    }
}
