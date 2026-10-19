// LoopFollow
// BolusEntryView.swift

import SwiftUI

struct BolusEntryView: View {
    let state: WatchState
    let remote: WatchRemoteConfig

    @Environment(\.dismiss) private var dismiss
    @State private var units = 0.0
    @State private var staleRecommendation: Double?
    @FocusState private var amountFocused: Bool

    /// Same cut-offs as the phone's bolus screens.
    private let recommendationMaxAge: TimeInterval = 12 * 60
    private let recommendationWarnAge: TimeInterval = 5 * 60

    private var step: Double { max(remote.bolusIncrement, 0.025) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                AmountField(value: $units, unit: "U", step: step, maximum: remote.maxBolus, isHighlighted: amountFocused, format: WatchFormat.insulin)
                    .focused($amountFocused)
                Text("Max \(WatchFormat.insulin(remote.maxBolus)) U")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                recommendation

                NavigationLink {
                    CommandConfirmView(
                        title: "Bolus",
                        lines: ["\(WatchFormat.insulin(units)) U"],
                        action: .bolus(units: units),
                        deliversInsulin: true,
                        onSuccess: { dismiss() }
                    )
                } label: {
                    Text("Continue")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(units <= 0)
            }
        }
        .navigationTitle("Bolus")
        .onAppear { amountFocused = true }
        .alert(
            "Old Calculation Warning",
            isPresented: Binding(get: { staleRecommendation != nil }, set: { if !$0 { staleRecommendation = nil } })
        ) {
            Button("Use Anyway") {
                if let staleRecommendation { units = staleRecommendation }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This recommended bolus was calculated more than 5 minutes ago. New treatments may have occurred since then. Proceed with caution.")
        }
    }

    @ViewBuilder
    private var recommendation: some View {
        if let rec = remote.recommendedBolus, rec > 0, let at = remote.recommendedBolusAt {
            let age = Date().timeIntervalSince(at)
            if age < recommendationMaxAge {
                let stepped = Self.roundedDown(min(rec, remote.maxBolus), step: step)
                Button {
                    if age >= recommendationWarnAge {
                        staleRecommendation = stepped
                    } else {
                        units = stepped
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended \(WatchFormat.insulin(stepped)) U")
                        Text("Calculated \(Int(age / 60)) min ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("New treatments may have occurred since the recommended bolus was calculated.")
                    .font(.caption2)
                    .foregroundStyle(age >= recommendationWarnAge ? .red : .yellow)
            }
        }
    }

    static func roundedDown(_ value: Double, step: Double) -> Double {
        let stepped = ((value / step) + 1e-10).rounded(.down) * step
        return (stepped * 1000).rounded() / 1000
    }
}

/// A value edited with the Digital Crown, in fixed steps between a minimum and a maximum.
struct AmountField: View {
    @Binding var value: Double
    let unit: String
    let step: Double
    var minimum: Double = 0
    let maximum: Double
    /// The caller owns focus; this only draws the highlight.
    let isHighlighted: Bool
    let format: (Double) -> String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(format(value))
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
            Text(unit)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).stroke(isHighlighted ? Color.green : Color.gray.opacity(0.4), lineWidth: 1.5))
        .focusable()
        .digitalCrownRotation($value, from: minimum, through: max(maximum, minimum + step), by: step, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: value) { _, newValue in
            let nearest = ((newValue / step).rounded() * step * 1000).rounded() / 1000
            let clamped = min(max(minimum, nearest), maximum)
            if clamped != newValue { value = clamped }
        }
    }
}
