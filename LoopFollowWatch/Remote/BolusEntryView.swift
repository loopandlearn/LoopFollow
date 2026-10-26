// LoopFollow
// BolusEntryView.swift

import SwiftUI
import WatchKit

/// The AID's recommendation and the phone's Quick-Pick boluses, opened from the
/// amount screen. Every choice still needs the crown confirmation.
struct BolusPresetsView: View {
    let remote: WatchRemoteConfig

    @EnvironmentObject private var navigator: WatchNavigator
    @State private var staleRecommendation: Double?

    /// Same cut-offs as the phone's bolus screens.
    private static let recommendationMaxAge: TimeInterval = 12 * 60
    static let recommendationWarnAge: TimeInterval = 5 * 60

    static func quickPicks(_ remote: WatchRemoteConfig) -> [Double] {
        remote.quickPickBoluses.filter { $0 > 0 && $0 <= remote.maxBolus }
    }

    /// A recommendation recent enough to offer, rounded down to the watch's step.
    static func freshRecommendation(_ remote: WatchRemoteConfig) -> (units: Double, age: TimeInterval)? {
        guard let rec = remote.recommendedBolus, rec > 0, let at = remote.recommendedBolusAt else { return nil }
        let age = Date().timeIntervalSince(at)
        let stepped = BolusAmountView.roundedDown(min(rec, remote.maxBolus), step: BolusAmountView.step(remote))
        guard age < recommendationMaxAge, stepped > 0 else { return nil }
        return (stepped, age)
    }

    static func hasPresets(_ remote: WatchRemoteConfig) -> Bool {
        freshRecommendation(remote) != nil || !quickPicks(remote).isEmpty
    }

    var body: some View {
        List {
            recommendation
            ForEach(Self.quickPicks(remote), id: \.self) { units in
                Button {
                    confirm(units)
                } label: {
                    Text("\(WatchFormat.insulin(units)) U")
                }
            }
        }
        .navigationTitle("Presets")
        .alert(
            "Old Calculation Warning",
            isPresented: Binding(get: { staleRecommendation != nil }, set: { if !$0 { staleRecommendation = nil } })
        ) {
            Button("Use Anyway") {
                if let staleRecommendation { confirm(staleRecommendation) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This recommended bolus was calculated more than 5 minutes ago. New treatments may have occurred since then. Proceed with caution.")
        }
    }

    @ViewBuilder
    private var recommendation: some View {
        if let rec = Self.freshRecommendation(remote) {
            Section {
                Button {
                    if rec.age >= Self.recommendationWarnAge {
                        staleRecommendation = rec.units
                    } else {
                        confirm(rec.units)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended \(WatchFormat.insulin(rec.units)) U")
                        Text("Calculated \(Int(rec.age / 60)) min ago")
                            .font(.caption2)
                            .foregroundStyle(rec.age >= Self.recommendationWarnAge ? .red : .secondary)
                    }
                }
            }
        }
    }

    private func confirm(_ units: Double) {
        navigator.push(.confirm(BolusAmountView.request(units)))
    }
}

/// Any amount, set with the Digital Crown or − and +, starting at the AID's
/// recommendation while it is under 5 minutes old; presets one tap away when
/// the phone has any.
struct BolusAmountView: View {
    let remote: WatchRemoteConfig

    @EnvironmentObject private var navigator: WatchNavigator
    @State private var units = 0.0
    /// Seeded once, so coming back from the confirmation keeps the user's amount.
    @State private var seeded = false
    @State private var seededRecommendation: (units: Double, age: TimeInterval)?
    @FocusState private var amountFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                AmountField(value: $units, unit: "U", step: Self.step(remote), maximum: remote.maxBolus, isHighlighted: amountFocused, sensitivity: .low, format: WatchFormat.insulin)
                    .focused($amountFocused)
                if let rec = seededRecommendation {
                    Label("\(WatchFormat.insulin(rec.units)) U, \(Int(rec.age / 60)) min ago", systemImage: "wand.and.stars")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Recommended \(WatchFormat.insulin(rec.units)) U, \(Int(rec.age / 60)) min ago")
                }
                Button("Continue") {
                    navigator.push(.confirm(Self.request(units)))
                }
                .buttonStyle(CompactButtonStyle(prominent: true))
                .tint(.blue)
                .disabled(units <= 0)
                if BolusPresetsView.hasPresets(remote) {
                    Button("Presets") {
                        navigator.push(.bolusPresets)
                    }
                    .buttonStyle(CompactButtonStyle())
                }
            }
        }
        .navigationTitle("Bolus")
        .onAppear {
            amountFocused = true
            guard !seeded else { return }
            seeded = true
            if let rec = BolusPresetsView.freshRecommendation(remote), rec.age < BolusPresetsView.recommendationWarnAge {
                units = rec.units
                seededRecommendation = rec
            }
        }
    }

    static func step(_ remote: WatchRemoteConfig) -> Double {
        max(remote.bolusIncrement, 0.025)
    }

    static func request(_ units: Double) -> CommandRequest {
        CommandRequest(title: "Bolus", lines: ["\(WatchFormat.insulin(units)) U"], action: .bolus(units: units), deliversInsulin: true)
    }

    static func roundedDown(_ value: Double, step: Double) -> Double {
        let stepped = ((value / step) + 1e-10).rounded(.down) * step
        return (stepped * 1000).rounded() / 1000
    }
}

/// A value edited with the Digital Crown or the − and + buttons, in fixed steps between a minimum and a maximum.
struct AmountField: View {
    @Binding var value: Double
    let unit: String
    let step: Double
    var minimum: Double = 0
    let maximum: Double
    /// The caller owns focus; this only draws the highlight.
    let isHighlighted: Bool
    var sensitivity: DigitalCrownRotationalSensitivity = .medium
    let format: (Double) -> String

    private var maxSteps: Double { max(((maximum - minimum) / step + 1e-10).rounded(.down), 0) }

    /// The crown works on whole step counts, so every detent is exactly one step.
    private var steps: Binding<Double> {
        Binding(
            get: { ((value - minimum) / step).rounded() },
            set: { newSteps in
                let clamped = min(max(newSteps.rounded(), 0), maxSteps)
                value = ((minimum + clamped * step) * 1000).rounded() / 1000
            }
        )
    }

    var body: some View {
        HStack(spacing: 2) {
            nudge("minus", by: -1)
                .disabled(steps.wrappedValue <= 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(format(value))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            nudge("plus", by: 1)
                .disabled(steps.wrappedValue >= maxSteps)
        }
        // Keeps − clear of the left edge, where watchOS takes swipes for going back.
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).stroke(isHighlighted ? Color.green : Color.gray.opacity(0.4), lineWidth: 1.5))
        .focusable()
        .digitalCrownRotation(detent: steps, from: 0, through: max(maxSteps, 1), by: 1, sensitivity: sensitivity, isContinuous: false, isHapticFeedbackEnabled: true)
    }

    private func nudge(_ symbol: String, by delta: Double) -> some View {
        Button {
            steps.wrappedValue += delta
            WKInterfaceDevice.current().play(.click)
        } label: {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
    }
}

/// A full-width capsule button shorter than the system's, scaled to the screen,
/// so an amount and two buttons fit without scrolling on every watch size.
struct CompactButtonStyle: ButtonStyle {
    var prominent = false

    @Environment(\.isEnabled) private var isEnabled

    /// About 34 pt on a 40 mm watch up to about 43 pt on the largest.
    private static let height = min(max(WKInterfaceDevice.current().screenBounds.height * 0.17, 32), 44)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(Capsule().fill(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.gray.opacity(0.3))))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}
