// LoopFollow
// SnoozeView.swift

import SwiftUI

struct SnoozeView: View {
    @Binding var isPresented: Bool
    let alertType: WatchAlertType?

    @StateObject private var settings = WatchAppSettings.shared
    @State private var snoozeMinutes: Double
    @State private var snoozeAll: Bool

    private let step: Double = 30
    private let range: ClosedRange<Double> = 30...720 // 30 min – 12 hr

    init(isPresented: Binding<Bool>, alertType: WatchAlertType?) {
        _isPresented = isPresented
        self.alertType = alertType
        let s = WatchAppSettings.shared
        _snoozeMinutes = State(initialValue: Double(s.defaultSnoozeMinutes))
        _snoozeAll = State(initialValue: s.snoozeAllByDefault)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Snooze Alerts")
                    .font(.headline)

                Text(formattedDuration)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .monospacedDigit()

                Slider(value: $snoozeMinutes, in: range, step: step)
                    .tint(.orange)

                // Scope toggle only shown when a specific alert type is known.
                // When opened manually (alertType == nil), snooze is always global.
                if alertType != nil {
                    Toggle("Snooze all alerts", isOn: $snoozeAll)
                        .font(.system(size: 13))
                        .toggleStyle(.switch)
                }

                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)

                    Button("Snooze") {
                        let target: WatchAlertType? = (snoozeAll || alertType == nil) ? nil : alertType
                        WatchAlertManager.shared.snooze(minutes: Int(snoozeMinutes), type: target)
                        isPresented = false
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var formattedDuration: String {
        let mins = Int(snoozeMinutes)
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
