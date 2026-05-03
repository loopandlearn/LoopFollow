// LoopFollow
// WatchMealView.swift

import SwiftUI
import WatchKit

struct WatchMealView: View {
    let config: WatchConfig
    @State private var carbs: Double = 0
    @State private var lastHapticCarbs: Int = 0
    @State private var confirmedCarbs: Int = 0
    @State private var showConfirm = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        VStack(spacing: 6) {
            if let result = resultMessage {
                Text(result)
                    .font(.system(size: 14))
                    .foregroundColor(isError ? .red : .green)
                    .multilineTextAlignment(.center)
            } else if showConfirm {
                Text("\(confirmedCarbs)g carbs")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)

                CrownConfirmView(label: "to send meal") {
                    sendMeal()
                }
            } else {
                Text("🍽️ Meal")
                    .font(.system(size: 16, weight: .semibold))

                Text("\(Int(carbs))g")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)

                Text("Max: \(Int(config.maxCarbs))g")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button("Confirm") {
                    if carbs > 0 {
                        confirmedCarbs = Int(carbs)
                        showConfirm = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .disabled(carbs <= 0)
            }
        }
        .focusable(!showConfirm)
        .digitalCrownRotation(
            $carbs,
            from: 0,
            through: config.maxCarbs,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: carbs) { _ in
            let current = Int(carbs)
            if current != lastHapticCarbs {
                lastHapticCarbs = current
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private func sendMeal() {
        WatchRemoteService.sendMeal(carbs: confirmedCarbs, config: config) { success, error in
            if success {
                resultMessage = "Meal sent!"
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }
}
