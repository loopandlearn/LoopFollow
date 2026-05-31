// LoopFollow
// WatchOverridePickerView.swift

import SwiftUI
import UserNotifications
import WatchConnectivity
import WatchKit

struct WatchOverridePickerView: View {
    @State private var presets: [WatchOverridePreset] = []
    @State private var selectedPreset: WatchOverridePreset?
    @State private var showConfirm = false
    @State private var isSending = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        List {
            if presets.isEmpty {
                Text("No override presets found.\nConfigure them in your Loop app.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(presets) { preset in
                    Button {
                        selectedPreset = preset
                        showConfirm = true
                    } label: {
                        HStack {
                            if let symbol = preset.symbol {
                                Text(symbol)
                                    .font(.title3)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(preset.durationDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isSending && selectedPreset?.name == preset.name {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                }
            }
        }
        .navigationTitle("Presets")
        .onAppear {
            presets = LAAppGroupSettings.watchOverridePresets()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        .confirmationDialog(
            selectedPreset.map { "Activate \($0.name)?" } ?? "Activate override?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let preset = selectedPreset {
                Button("Activate") { sendOverride(preset) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func sendOverride(_ preset: WatchOverridePreset) {
        guard WCSession.default.isReachable else {
            alertMessage = "Phone not reachable. Bring your iPhone closer."
            showAlert = true
            return
        }
        isSending = true
        let payload: [String: Any] = [
            "watchCmd": "override",
            "overrideName": preset.name,
            "overrideDuration": preset.durationSeconds,
        ]
        WCSession.default.sendMessage(payload) { reply in
            DispatchQueue.main.async {
                isSending = false
                let ok = reply["success"] as? Bool ?? false
                alertMessage = ok
                    ? "\(preset.name) activated!"
                    : (reply["error"] as? String ?? "Failed to activate override")
                if ok { scheduleSuccessNotification(name: preset.name) }
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

    private func scheduleSuccessNotification(name: String) {
        WKInterfaceDevice.current().play(.success)
        let content = UNMutableNotificationContent()
        content.title = "Override Activated ✓"
        content.body = "\(name) sent to Loop"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "override-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}

private extension WatchOverridePreset {
    var durationDescription: String {
        if durationSeconds == 0 { return "Indefinite" }
        let h = Int(durationSeconds) / 3600
        let m = Int(durationSeconds) % 3600 / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}
