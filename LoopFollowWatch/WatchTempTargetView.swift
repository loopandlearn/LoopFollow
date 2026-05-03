// LoopFollow
// WatchTempTargetView.swift

import SwiftUI

struct WatchTempTargetView: View {
    let config: WatchConfig
    @State private var mode: ViewMode = .menu
    @State private var customTarget: Double = 120
    @State private var customDuration: Double = 60
    @State private var editingField: EditField = .target
    @State private var showConfirm = false
    @State private var pendingTarget: Int = 0
    @State private var pendingDuration: Int = 0
    @State private var resultMessage: String?
    @State private var isError = false

    enum ViewMode {
        case menu, custom
    }

    enum EditField {
        case target, duration
    }

    /// The value bound to the crown depending on which field is being edited
    private var crownBinding: Binding<Double> {
        switch editingField {
        case .target:
            return $customTarget
        case .duration:
            return $customDuration
        }
    }

    private var crownRange: ClosedRange<Double> {
        switch editingField {
        case .target:
            return 60...300
        case .duration:
            return 5...480
        }
    }

    private var crownStep: Double {
        switch editingField {
        case .target: return 5
        case .duration: return 5
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let result = resultMessage {
                    Text(result)
                        .font(.system(size: 14))
                        .foregroundColor(isError ? .red : .green)
                        .multilineTextAlignment(.center)
                } else if showConfirm {
                    Text("\(pendingTarget) \(config.units == "mmol/L" ? "mmol/L" : "mg/dL") for \(pendingDuration)m")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pink)

                    CrownConfirmView(label: "to set target") {
                        sendTempTarget()
                    }
                } else if mode == .custom {
                    Text("🎯 Custom Target")
                        .font(.system(size: 14, weight: .semibold))

                    // Target row — tappable to select for crown editing
                    Button {
                        editingField = .target
                    } label: {
                        HStack {
                            Text("Target:")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(config.units == "mmol/L"
                                ? String(format: "%.1f", customTarget * 0.0555)
                                : "\(Int(customTarget))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(editingField == .target ? .pink : .primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(editingField == .target ? Color.pink.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Duration row — tappable to select for crown editing
                    Button {
                        editingField = .duration
                    } label: {
                        HStack {
                            Text("Duration:")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int(customDuration))m")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(editingField == .duration ? .pink : .primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(editingField == .duration ? Color.pink.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Text("Tap a field, then scroll crown")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button("Back") {
                            mode = .menu
                        }
                        .font(.system(size: 12))

                        Button("Set") {
                            pendingTarget = Int(customTarget)
                            pendingDuration = Int(customDuration)
                            showConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .font(.system(size: 12))
                    }
                } else {
                    // Menu mode
                    Text("🎯 Temp Target")
                        .font(.system(size: 14, weight: .semibold))

                    // Presets
                    Button("Exercise: 150 / 60m") {
                        pendingTarget = 150
                        pendingDuration = 60
                        showConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink.opacity(0.6))

                    Button("Eating Soon: 80 / 60m") {
                        pendingTarget = 80
                        pendingDuration = 60
                        showConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink.opacity(0.6))

                    // Custom
                    Divider()

                    Button("Custom...") {
                        mode = .custom
                        editingField = .target
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)

                    Divider()

                    // Cancel
                    Button("Cancel Active") {
                        cancelTarget()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .focusable(mode == .custom && !showConfirm)
        .digitalCrownRotation(
            crownBinding,
            from: crownRange.lowerBound,
            through: crownRange.upperBound,
            by: crownStep,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }

    private func sendTempTarget() {
        WatchRemoteService.sendTempTarget(target: pendingTarget, duration: pendingDuration, config: config) { success, error in
            if success {
                resultMessage = "Target set!"
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }

    private func cancelTarget() {
        WatchRemoteService.cancelTempTarget(config: config) { success, error in
            if success {
                resultMessage = "Target cancelled"
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }
}
