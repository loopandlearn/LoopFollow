// LoopFollow
// BolusEntryView.swift

import SwiftUI
import WatchKit

/// The AID's recommendation at the watch's bolus step.
struct BolusRecommendation: Hashable {
    let units: Double
    let at: Date

    var age: TimeInterval { Date().timeIntervalSince(at) }
}

/// The AID's recommendation and the phone's Quick-Pick boluses, opened from the
/// amount screen. Every choice still needs the crown confirmation.
struct BolusPresetsView: View {
    let remote: WatchRemoteConfig

    @EnvironmentObject private var navigator: WatchNavigator
    @State private var staleRecommendation: BolusRecommendation?

    /// Same cut-offs and warning as the phone's bolus screens.
    static let recommendationMaxAge: TimeInterval = 12 * 60
    static let recommendationWarnAge: TimeInterval = 5 * 60
    static let oldCalculationWarning = "This recommended bolus was calculated more than 5 minutes ago. New treatments may have occurred since then. Proceed with caution."

    static func quickPicks(_ remote: WatchRemoteConfig) -> [Double] {
        remote.quickPickBoluses.filter { $0 > 0 && $0 <= remote.maxBolus }
    }

    /// The latest recommendation whatever its age, rounded down to the watch's
    /// step; nil when the loop cycle carries none, or ran before insulin was
    /// last sent from the watch and so leaves that insulin out. The phone drops
    /// one from before any other bolus.
    static func latestRecommendation(_ remote: WatchRemoteConfig) -> BolusRecommendation? {
        guard let at = remote.recommendedBolusAt, let recommended = remote.recommendedBolus else { return nil }
        if let sent = WatchSession.lastInsulinSentAt, at <= sent { return nil }
        let rec = max(recommended, 0)
        return BolusRecommendation(units: BolusAmountView.roundedDown(min(rec, remote.maxBolus), step: BolusAmountView.step(remote)), at: at)
    }

    /// A recommendation recent enough to offer.
    static func freshRecommendation(_ remote: WatchRemoteConfig) -> BolusRecommendation? {
        guard let rec = latestRecommendation(remote), rec.units > 0, rec.age < recommendationMaxAge else { return nil }
        return rec
    }

    /// Under 5 minutes old the recommendation is already the starting amount,
    /// so it is only listed here once it needs the warning.
    static func presetRecommendation(_ remote: WatchRemoteConfig) -> BolusRecommendation? {
        guard let rec = freshRecommendation(remote), rec.age >= recommendationWarnAge else { return nil }
        return rec
    }

    static func hasPresets(_ remote: WatchRemoteConfig) -> Bool {
        presetRecommendation(remote) != nil || !quickPicks(remote).isEmpty
    }

    var body: some View {
        List {
            recommendation
            ForEach(Self.quickPicks(remote), id: \.self) { units in
                Button {
                    navigator.push(.confirm(BolusAmountView.request(units)))
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
                if let staleRecommendation {
                    navigator.push(.confirm(BolusAmountView.request(staleRecommendation.units, recommendation: staleRecommendation)))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Self.oldCalculationWarning)
        }
    }

    @ViewBuilder
    private var recommendation: some View {
        if let rec = Self.presetRecommendation(remote) {
            Section {
                Button {
                    staleRecommendation = rec
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended \(WatchFormat.insulin(rec.units)) U")
                        Text("Calculated \(Int(rec.age / 60)) min ago")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

/// Any amount, set with the Digital Crown or − and +, starting at the AID's
/// recommendation while it is under 5 minutes old. Until the amount is changed
/// by hand, a newer recommendation that is lower or the same replaces it, and a
/// higher one is offered with a tap. A starting recommendation past 12 minutes
/// is cleared at Continue. Presets are one tap away when the phone has any.
struct BolusAmountView: View {
    let remote: WatchRemoteConfig

    @EnvironmentObject private var session: WatchSession
    @EnvironmentObject private var navigator: WatchNavigator
    @State private var units = 0.0
    /// Seeded once, so coming back from the confirmation keeps the user's amount.
    @State private var seeded = false
    @State private var seededRecommendation: BolusRecommendation?
    /// True until the amount is changed by hand.
    @State private var followsRecommendation = true
    /// A newer, higher recommendation, only applied when tapped.
    @State private var higherRecommendation: BolusRecommendation?
    /// Recommendations are followed only while this screen is on top; the
    /// confirmation checks its own amount.
    @State private var isVisible = false
    @State private var showOldCalculationWarning = false
    @State private var showExpiredRecommendation = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                AmountField(value: $units, unit: "U", step: Self.step(remote), maximum: remote.maxBolus, isHighlighted: amountFocused, sensitivity: .low, format: WatchFormat.insulin)
                    .focused($amountFocused)
                if let higher = higherRecommendation, higher.units != units {
                    Button {
                        seededRecommendation = higher
                        units = higher.units
                        followsRecommendation = true
                        higherRecommendation = nil
                        amountFocused = true
                    } label: {
                        Label("New \(WatchFormat.insulin(higher.units)) U, tap to use", systemImage: "wand.and.stars")
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Use the new, higher recommendation, \(WatchFormat.insulin(higher.units)) U")
                } else if let rec = seededRecommendation {
                    // Redrawn every few seconds so the age keeps counting while the screen stays open.
                    TimelineView(.periodic(from: .now, by: 10)) { context in
                        let age = context.date.timeIntervalSince(rec.at)
                        Label("\(WatchFormat.insulin(rec.units)) U, \(Int(age / 60)) min ago", systemImage: "wand.and.stars")
                            .font(.footnote)
                            .foregroundStyle(age >= BolusPresetsView.recommendationWarnAge ? .red : .secondary)
                            .accessibilityLabel("Recommended \(WatchFormat.insulin(rec.units)) U, \(Int(age / 60)) min ago")
                    }
                }
                Button("Continue") {
                    if let age = startingRecommendationAge, age >= BolusPresetsView.recommendationMaxAge {
                        showExpiredRecommendation = true
                    } else if let age = startingRecommendationAge, age >= BolusPresetsView.recommendationWarnAge {
                        showOldCalculationWarning = true
                    } else {
                        continueToConfirm()
                    }
                }
                .buttonStyle(CompactButtonStyle(prominent: true))
                .tint(.blue)
                .disabled(units <= 0)
                // Redrawn so the button appears once the recommendation is old enough to be listed there.
                TimelineView(.periodic(from: .now, by: 10)) { _ in
                    if BolusPresetsView.hasPresets(remote) {
                        Button("Presets") {
                            navigator.push(.bolusPresets)
                        }
                        .buttonStyle(CompactButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("Bolus")
        .alert("Old Calculation Warning", isPresented: $showOldCalculationWarning) {
            Button("Use Anyway") {
                continueToConfirm()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(BolusPresetsView.oldCalculationWarning)
        }
        .alert("Recommendation Expired", isPresented: $showExpiredRecommendation) {
            Button("OK") {
                seededRecommendation = nil
                units = 0
                followsRecommendation = true
            }
        } message: {
            Text("This recommended bolus was calculated more than 12 minutes ago. Set the amount again.")
        }
        .onAppear {
            isVisible = true
            amountFocused = true
            guard !seeded else {
                // Catches up on a cycle that came in while another screen was on top.
                followNewerRecommendation()
                return
            }
            seeded = true
            // The phone also sends new loop cycles as they come; this covers one it has not sent yet.
            session.requestState()
            if let rec = BolusPresetsView.freshRecommendation(remote), rec.age < BolusPresetsView.recommendationWarnAge {
                seededRecommendation = rec
                units = rec.units
            }
        }
        .onDisappear { isVisible = false }
        .onChange(of: units) { _, newUnits in
            if newUnits != (seededRecommendation?.units ?? 0) { followsRecommendation = false }
        }
        .onChange(of: session.state?.remote?.recommendedBolusAt) { _, _ in
            followNewerRecommendation()
        }
    }

    /// An untouched amount moves down to a newer, lower recommendation; a
    /// higher one, or the first fresh one when nothing was filled in, is only
    /// offered, so insulin is never raised without a tap.
    private func followNewerRecommendation() {
        guard isVisible, followsRecommendation,
              let latest = session.state?.remote.flatMap(BolusPresetsView.latestRecommendation),
              latest != higherRecommendation
        else { return }
        if let seededRecommendation {
            guard latest.at > seededRecommendation.at else { return }
        } else {
            guard latest.units > 0, latest.age < BolusPresetsView.recommendationWarnAge else { return }
        }
        let previousUnits = units
        if latest.units > units {
            higherRecommendation = latest
        } else {
            seededRecommendation = latest
            units = latest.units
            higherRecommendation = nil
        }
        if latest.units != previousUnits {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    /// Age of the starting recommendation while it is still the amount. A newer,
    /// higher recommendation means the old one no longer risks too much insulin.
    private var startingRecommendationAge: TimeInterval? {
        guard let rec = seededRecommendation, units == rec.units, higherRecommendation == nil else { return nil }
        return rec.age
    }

    static func step(_ remote: WatchRemoteConfig) -> Double {
        max(remote.bolusIncrement, 0.025)
    }

    /// The recommendation goes along only while the amount is still the recommendation.
    private func continueToConfirm() {
        let basis = seededRecommendation.flatMap { $0.units == units ? $0 : nil }
        navigator.push(.confirm(Self.request(units, recommendation: basis)))
    }

    static func request(_ units: Double, recommendation: BolusRecommendation? = nil) -> CommandRequest {
        CommandRequest(title: "Bolus", lines: ["\(WatchFormat.insulin(units)) U"], action: .bolus(units: units), deliversInsulin: true, recommendation: recommendation)
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
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(Capsule().fill(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.gray.opacity(0.3))))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}
