// LoopFollow
// WatchMealCommandView.swift
// Carbs remote command view for Watch.

import SwiftUI
import UserNotifications
import WatchConnectivity
import WatchKit

struct WatchMealCommandView: View {
    // Absorption presets: (emoji, hours)
    private let foodPresets: [(String, Double)] = [("🍭", 0.5), ("🌮", 3.0), ("🍕", 5.0)]

    @State private var carbsGrams: Int = 20
    @State private var selectedFood: Int = 1  // default: taco (3 hr)
    @State private var showConfirm = false
    @State private var isSending = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var alertIsSuccess = false

    private var maxCarbs: Int { max(5, Int(LAAppGroupSettings.watchMaxCarbs())) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Carbs stepper
                VStack(spacing: 4) {
                    Text("\(carbsGrams)g")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    HStack(spacing: 16) {
                        Button { carbsGrams = max(5, carbsGrams - 5) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Button { carbsGrams = min(maxCarbs, carbsGrams + 5) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // Food type selector
                HStack(spacing: 8) {
                    ForEach(0..<foodPresets.count, id: \.self) { idx in
                        let (emoji, _) = foodPresets[idx]
                        Button {
                            selectedFood = idx
                        } label: {
                            Text(emoji)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(selectedFood == idx ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.15))
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("\(Int(foodPresets[selectedFood].1 * 60)) min absorption")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Send button
                Button {
                    showConfirm = true
                } label: {
                    Text("Send Carbs")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || carbsGrams <= 0)
                .confirmationDialog("Send \(carbsGrams)g carbs?", isPresented: $showConfirm, titleVisibility: .visible) {
                    Button("Send") { sendCarbs() }
                    Button("Cancel", role: .cancel) {}
                }

                if isSending {
                    ProgressView("Sending…")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Meal")
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func sendCarbs() {
        guard WCSession.default.isReachable else {
            alertMessage = "Phone not reachable. Bring your iPhone closer."
            showAlert = true
            return
        }
        isSending = true
        let (_, absorptionHours) = foodPresets[selectedFood]
        let payload: [String: Any] = [
            "watchCmd": "carbs",
            "carbsAmount": Double(carbsGrams),
            "absorptionTime": absorptionHours
        ]
        WCSession.default.sendMessage(payload) { reply in
            DispatchQueue.main.async {
                isSending = false
                let ok = reply["success"] as? Bool ?? false
                let totpBlocked = reply["totpBlocked"] as? Bool ?? false
                if totpBlocked {
                    alertMessage = "OTP code already used. Wait up to 30 seconds and try again."
                } else {
                    alertMessage = ok ? "Carbs sent! (\(carbsGrams)g)" : (reply["error"] as? String ?? "Failed to send carbs")
                }
                if ok { scheduleSuccessNotification(grams: carbsGrams) }
                showAlert = true
            }
        } errorHandler: { error in
            DispatchQueue.main.async {
                isSending = false
                alertMessage = "Send error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func scheduleSuccessNotification(grams: Int) {
        WKInterfaceDevice.current().play(.success)
        let content = UNMutableNotificationContent()
        content.title = "Carbs Logged ✓"
        content.body = "\(grams)g sent to Loop"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "carbs-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
