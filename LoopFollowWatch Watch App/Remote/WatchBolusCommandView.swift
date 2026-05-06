// LoopFollow
// WatchBolusCommandView.swift
// Bolus remote command view for Watch with passcode authentication.

import LocalAuthentication
import SwiftUI
import UserNotifications
import WatchConnectivity
import WatchKit

struct WatchBolusCommandView: View {
    let snapshot: GlucoseSnapshot?

    @State private var bolusUnits: Double
    @State private var showConfirm = false
    @State private var isSending = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var maxBolus: Double { max(0.05, LAAppGroupSettings.watchMaxBolus()) }
    private let step = 0.05

    private var recBolus: Double? { snapshot?.recBolus }

    private var recBolusAge: Int? {
        guard let t = snapshot?.loopLastRunAt else { return nil }
        let mins = Int(Date().timeIntervalSince1970 - t) / 60
        return mins < 12 ? mins : nil
    }

    init(snapshot: GlucoseSnapshot?) {
        self.snapshot = snapshot
        let maxB = max(0.05, LAAppGroupSettings.watchMaxBolus())
        let rec = snapshot?.recBolus ?? 0
        _bolusUnits = State(initialValue: rec > 0 ? min(rec, maxB).rounded(toPlaces: 2) : 0.05)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Recommended bolus tap-to-set row
                if let rec = recBolus, rec > 0, let age = recBolusAge {
                    Button {
                        bolusUnits = min(rec, maxBolus).rounded(toPlaces: 2)
                    } label: {
                        VStack(spacing: 2) {
                            Text("Rec: \(String(format: "%.2f", rec))U")
                                .font(.headline)
                            Text("\(age)m ago\(age >= 5 ? " ⚠" : "")")
                                .font(.caption2)
                                .foregroundColor(age >= 5 ? .yellow : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // Bolus amount stepper
                VStack(spacing: 4) {
                    Text(String(format: "%.2fU", bolusUnits))
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    HStack(spacing: 16) {
                        Button {
                            bolusUnits = max(0.05, (bolusUnits - step).rounded(toPlaces: 2))
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Button {
                            bolusUnits = min(maxBolus, (bolusUnits + step).rounded(toPlaces: 2))
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Send button
                Button {
                    showConfirm = true
                } label: {
                    Text("Send Bolus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isSending || bolusUnits <= 0)
                .confirmationDialog("Send \(String(format: "%.2f", bolusUnits))U insulin?", isPresented: $showConfirm, titleVisibility: .visible) {
                    Button("Authenticate & Send", role: .destructive) { authenticateAndSend() }
                    Button("Cancel", role: .cancel) {}
                }

                if isSending {
                    ProgressView("Sending…")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Bolus")
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func authenticateAndSend() {
        let context = LAContext()
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            sendBolus()
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                                localizedReason: "Confirm identity to send \(String(format: "%.2f", bolusUnits))U insulin") { success, _ in
            DispatchQueue.main.async {
                if success { sendBolus() } else {
                    alertMessage = "Authentication failed or cancelled"
                    showAlert = true
                }
            }
        }
    }

    private func sendBolus() {
        guard WCSession.default.isReachable else {
            alertMessage = "Phone not reachable. Bring your iPhone closer."
            showAlert = true
            return
        }
        isSending = true
        let units = bolusUnits
        let payload: [String: Any] = ["watchCmd": "bolus", "bolusAmount": units]
        WCSession.default.sendMessage(payload) { reply in
            DispatchQueue.main.async {
                isSending = false
                let ok = reply["success"] as? Bool ?? false
                let totpBlocked = reply["totpBlocked"] as? Bool ?? false
                if totpBlocked {
                    alertMessage = "OTP code already used. Wait up to 30 seconds and try again."
                    showAlert = true
                } else if ok {
                    scheduleSuccessNotification(units: units)
                    alertMessage = "Bolus sent! (\(String(format: "%.2f", units))U)"
                    showAlert = true
                } else {
                    alertMessage = reply["error"] as? String ?? "Failed to send bolus"
                    showAlert = true
                }
            }
        } errorHandler: { error in
            DispatchQueue.main.async {
                isSending = false
                alertMessage = "Send error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func scheduleSuccessNotification(units: Double) {
        WKInterfaceDevice.current().play(.success)
        let content = UNMutableNotificationContent()
        content.title = "Bolus Sent ✓"
        content.body = String(format: "%.2fU sent to Loop", units)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "bolus-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
