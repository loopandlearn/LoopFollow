// LoopFollow
// WatchBolusView.swift

import SwiftUI
import WatchKit

struct WatchBolusView: View {
    let config: WatchConfig
    @State private var rawCrown: Double = 0
    @State private var lastHapticAmount: Double = 0
    @State private var confirmedAmount: Double = 0
    @State private var showConfirm = false
    @State private var resultMessage: String?
    @State private var isError = false

    /// The displayed amount, snapped to 0.05U increments
    private var amount: Double {
        let scaled = rawCrown * 0.25
        let snapped = (scaled / 0.05).rounded() * 0.05
        return min(max(snapped, 0), config.maxBolus)
    }

    var body: some View {
        VStack(spacing: 6) {
            if let result = resultMessage {
                Text(result)
                    .font(.system(size: 14))
                    .foregroundColor(isError ? .red : .green)
                    .multilineTextAlignment(.center)
            } else if showConfirm {
                Text(String(format: "%.2f U", confirmedAmount))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)

                CrownConfirmView(label: "to deliver") {
                    sendBolus()
                }
            } else {
                Text("💧 Bolus")
                    .font(.system(size: 16, weight: .semibold))

                Text(String(format: "%.2f U", amount))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)

                Text("Max: \(String(format: "%.1f", config.maxBolus))U")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button("Confirm") {
                    if amount > 0 {
                        confirmedAmount = amount
                        showConfirm = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(amount <= 0)
            }
        }
        .focusable(!showConfirm)
        .digitalCrownRotation(
            Binding(
                get: { showConfirm ? 0 : rawCrown },
                set: { if !showConfirm { rawCrown = $0 } }
            ),
            from: 0,
            through: config.maxBolus / 0.25,
            by: 0.01,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: false // no built-in haptic — we fire manually
        )
        .onChange(of: rawCrown) { _ in
            let current = amount
            if current != lastHapticAmount {
                lastHapticAmount = current
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private func sendBolus() {
        WatchRemoteService.sendBolus(amount: confirmedAmount, config: config) { success, error in
            if success {
                resultMessage = "Bolus sent!"
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }
}
