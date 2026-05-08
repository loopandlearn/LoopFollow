// LoopFollow
// WatchBolusView.swift

import SwiftUI
import WatchKit

/// Optional meal data passed from the meal screen for the meal→bolus flow.
struct PendingMealData {
    let carbs: Int
    let protein: Int?
    let fat: Int?
    let timeOffset: Double // minutes offset from now
}

struct WatchBolusView: View {
    let config: WatchConfig
    @ObservedObject var bgFetcher: BGFetcher
    var pendingMeal: PendingMealData?
    var popToRoot: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var rawCrown: Double = 0
    @State private var lastHapticAmount: Double = 0
    @State private var confirmedAmount: Double = 0
    @State private var showConfirm = false
    @State private var resultMessage: String?
    @State private var isError = false
    @State private var showCalcDetail = false
    @State private var showCelebration = false

    /// The displayed amount, snapped to 0.05U increments
    private var amount: Double {
        let scaled = rawCrown * 0.25
        let snapped = (scaled / 0.05).rounded() * 0.05
        return min(max(snapped, 0), config.maxBolus)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let result = resultMessage {
                ZStack {
                    VStack {
                        Spacer()
                        Text(result)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isError ? .red : .green)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    CelebrationOverlay(isActive: $showCelebration)
                }
            } else if showConfirm {
                confirmSummary
                    .padding(.bottom, 12)

                CrownConfirmView(label: confirmedAmount > 0 ? "to deliver" : "to send meal") {
                    sendBolusAndMeal()
                }

            } else {
                HStack {
                    Button {
                        rawCrown = max(rawCrown - 1.0, 0)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("−")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    // Extra padding so the tap target doesn't bleed
                    // into the system back button zone on small watches.
                    .padding(.leading, 8)

                    Spacer()

                    Text("Bolus")
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    Button {
                        rawCrown = min(rawCrown + 1.0, config.maxBolus / 0.25)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("+")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text(String(format: "%.2f U", amount))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    Text("Calculated: \(String(format: "%.2f", bgFetcher.recommendedBolus))U")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .onTapGesture {
                            rawCrown = min(bgFetcher.recommendedBolus, config.maxBolus) / 0.25
                        }
                    if bgFetcher.bolusCalc != nil {
                        Button {
                            showCalcDetail = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.blue.opacity(0.8))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 8)
                .padding(.top, -8)

                Button(amount > 0 ? "Confirm" : (pendingMeal != nil ? "Skip" : "Confirm")) {
                    confirmedAmount = amount
                    showConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(amount <= 0 && pendingMeal == nil)
            }
        }
        .modifier(CrownRotationModifier(
            isActive: !showConfirm && resultMessage == nil,
            value: $rawCrown,
            from: 0,
            through: config.maxBolus / 0.25,
            by: 0.01,
            sensitivity: .low
        ))
        .onChange(of: rawCrown) { _ in
            let current = amount
            if current != lastHapticAmount {
                lastHapticAmount = current
                WKInterfaceDevice.current().play(.click)
            }
        }
        .sheet(isPresented: $showCalcDetail) {
            if let calc = bgFetcher.bolusCalc {
                BolusCalcDetailView(calc: calc, recommended: bgFetcher.recommendedBolus)
            }
        }
        .navigationBarBackButtonHidden(showConfirm)
        .toolbar {
            if showConfirm {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showConfirm = false
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .onAppear {
            // If launched directly (not from meal entry), clear any stale pending carbs
            if pendingMeal == nil {
                bgFetcher.pendingCarbs = 0
            }
            bgFetcher.updateRecommendedBolus()
        }
        .onDisappear {
            bgFetcher.pendingCarbs = 0
        }
    }

    @ViewBuilder
    private var confirmSummary: some View {
        VStack(spacing: 4) {
            Label(String(format: "%.2f U", confirmedAmount), systemImage: "drop.fill")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(confirmedAmount > 0 ? .blue : .secondary)
            if let meal = pendingMeal {
                HStack(spacing: 8) {
                    Label("\(meal.carbs)g", systemImage: "fork.knife")
                        .foregroundColor(.yellow)
                    if let f = meal.fat, f > 0 {
                        Label("\(f)g", systemImage: "circle.hexagongrid.fill")
                            .foregroundColor(.orange)
                    }
                    if let p = meal.protein, p > 0 {
                        Label("\(p)g", systemImage: "figure.strengthtraining.functional")
                            .foregroundColor(.orange)
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
    }

    private func autoDismiss() {
        let delay = showCelebration ? CelebrationOverlay.displayDuration : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let popToRoot = popToRoot {
                popToRoot()
            } else {
                dismiss()
            }
        }
    }

    private func sendBolusAndMeal() {
        if confirmedAmount > 0 {
            // Send bolus first — if carbs arrived before the bolus, Trio could
            // auto-dose on the carbs and stack with our remote bolus.
            sendBolus()
        } else if let meal = pendingMeal {
            // Skip (0U) — send meal only
            sendMeal(meal)
        }
    }

    private func sendBolus() {
        WatchRemoteService.sendBolus(amount: confirmedAmount, config: config) { success, error in
            if success {
                bgFetcher.pendingInsulin += confirmedAmount
                bgFetcher.updateRecommendedBolus()
                if let meal = pendingMeal {
                    // Bolus succeeded — now safe to send carbs
                    sendMeal(meal)
                } else {
                    bgFetcher.pendingCarbs = 0
                    resultMessage = "Bolus sent!"
                    showCelebration = CelebrationOverlay.shouldCelebrate()
                    WatchRemoteService.postLocalNotification(
                        title: "Bolus Sent",
                        body: String(format: "%.2fU bolus command sent", confirmedAmount)
                    )
                    autoDismiss()
                }
            } else {
                bgFetcher.pendingCarbs = 0
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }

    private func sendMeal(_ meal: PendingMealData) {
        let mealProtein = (config.mealWithFatProtein && meal.protein != nil && meal.protein! > 0) ? meal.protein : nil
        let mealFat = (config.mealWithFatProtein && meal.fat != nil && meal.fat! > 0) ? meal.fat : nil
        let mealTime = abs(meal.timeOffset) >= 1 ? Date().addingTimeInterval(meal.timeOffset * 60) : nil

        WatchRemoteService.sendMeal(
            carbs: meal.carbs,
            protein: mealProtein,
            fat: mealFat,
            entryTime: mealTime,
            config: config
        ) { success, error in
            // Always clear pending carbs — whether the send succeeded or failed,
            // the meal flow is done and we must not double-count.
            bgFetcher.pendingCarbs = 0

            if success {
                if confirmedAmount > 0 {
                    resultMessage = "Bolus + Meal\nsent!"
                    showCelebration = CelebrationOverlay.shouldCelebrate()
                    WatchRemoteService.postLocalNotification(
                        title: "Bolus + Meal Sent",
                        body: String(format: "%.2fU bolus + %dg carbs", confirmedAmount, meal.carbs)
                    )
                } else {
                    resultMessage = "Meal sent!"
                    showCelebration = CelebrationOverlay.shouldCelebrate()
                    WatchRemoteService.postLocalNotification(
                        title: "Meal Sent",
                        body: "\(meal.carbs)g carbs logged"
                    )
                }
                autoDismiss()
            } else {
                resultMessage = error ?? "Meal failed"
                isError = true
            }
        }
    }
}

private struct BolusCalcDetailView: View {
    let calc: BolusCalculation
    let recommended: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bolus Calculation")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                calcRow(
                    label: "GLUCOSE",
                    detail: "(\(fmtInt(calc.bg)) − \(fmtInt(calc.target))) / \(fmtInt(calc.isf))",
                    result: calc.glucoseEffect
                )

                calcRow(
                    label: "IOB",
                    detail: "−1 × \(fmt(calc.iob))",
                    result: calc.iobEffect
                )

                let totalCarbs = calc.cob + calc.pendingCarbs
                calcRow(
                    label: "COB",
                    detail: "(\(fmtInt(calc.cob)) + \(fmtInt(calc.pendingCarbs))) / \(fmtInt(calc.cr))",
                    result: calc.cobEffect
                )

                calcRow(
                    label: "DELTA",
                    detail: "\(fmtInt(calc.delta)) / \(fmtInt(calc.isf))",
                    result: calc.deltaEffect
                )

                Divider()

                HStack {
                    Text("Full Bolus")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(fmt(calc.fullBolus))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(calc.fullBolus >= 0 ? .green : .red)
                }

                HStack {
                    Text("Recommended")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(fmt(recommended)) U")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func calcRow(label: String, detail: String, result: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            HStack {
                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                Text(fmt(result))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(result >= 0 ? .green : .red)
            }
        }
    }

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
    private func fmtInt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
