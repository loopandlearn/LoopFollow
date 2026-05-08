// LoopFollow
// WatchTempTargetView.swift

import SwiftUI

private let tempColor = Color(red: 0.2, green: 0.9, blue: 0.1)

struct WatchTempTargetView: View {
    let config: WatchConfig
    @ObservedObject var bgFetcher: BGFetcher
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false
    @State private var pendingTarget: Int = 0
    @State private var pendingDuration: Int = 0
    @State private var resultMessage: String?
    @State private var isError = false
    @State private var showCelebration = false

    var body: some View {
        Group {
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
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        if showConfirm {
                            Text("\(pendingTarget) \(config.units == "mmol/L" ? "mmol/L" : "mg/dL") for \(pendingDuration)m")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(tempColor)

                            CrownConfirmView(label: "to set target") {
                                sendTempTarget()
                            }
                        } else {
                            // Active temp target section (check both devicestatus and treatments)
                            if let activeTT = activeTempTargetEntry {
                                Text("Active Temp Target")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text("\(Int(activeTT.targetBottom))-\(Int(activeTT.targetTop)) mg/dL" + (activeTT.reason.isEmpty ? "" : " (\(activeTT.reason))"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .background(Color.green.opacity(0.3))
                                    .cornerRadius(8)

                                Button {
                                    cancelTarget()
                                } label: {
                                    Text("Cancel Temp Target")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.red.opacity(0.3))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }

                            Text("Temp Targets")
                                .font(.system(size: 14, weight: .semibold))

                            Button {
                                pendingTarget = 160
                                pendingDuration = 180
                                showConfirm = true
                            } label: {
                                Text("Exercise: 160 / 3h")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(tempColor.opacity(0.55))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button {
                                pendingTarget = 80
                                pendingDuration = 120
                                showConfirm = true
                            } label: {
                                Text("Mealtime: 80 / 2h")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(tempColor.opacity(0.55))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Divider()

                            NavigationLink {
                                CustomTempTargetView(config: config, bgFetcher: bgFetcher)
                            } label: {
                                Text("Custom...")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(tempColor)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// Returns the currently active temp target from treatments, or nil if none active.
    private var activeTempTargetEntry: TempTargetEntry? {
        let now = Date()
        return bgFetcher.tempTargetEntries.first { $0.startDate <= now && $0.endDate > now }
    }

    private func autoDismiss() {
        let delay = showCelebration ? CelebrationOverlay.displayDuration : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            dismiss()
        }
    }

    private func sendTempTarget() {
        WatchRemoteService.sendTempTarget(target: pendingTarget, duration: pendingDuration, config: config) { success, error in
            if success {
                resultMessage = "Target set!"
                showCelebration = CelebrationOverlay.shouldCelebrate()
                WatchRemoteService.postLocalNotification(
                    title: "Temp Target Set",
                    body: "\(pendingTarget) mg/dL for \(pendingDuration)m"
                )
                autoDismiss()
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
                showCelebration = CelebrationOverlay.shouldCelebrate()
                WatchRemoteService.postLocalNotification(
                    title: "Temp Target Cancelled",
                    body: "Temp target cancel command sent"
                )
                autoDismiss()
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }
}

// MARK: - Custom Target (pushed via NavigationLink)

private struct CustomTempTargetView: View {
    let config: WatchConfig
    @ObservedObject var bgFetcher: BGFetcher
    @Environment(\.dismiss) private var dismiss
    @State private var customTarget: Double = 120
    @State private var customDuration: Double = 60
    @State private var editingField: EditField = .target
    @State private var showConfirm = false
    @State private var pendingTarget: Int = 0
    @State private var pendingDuration: Int = 0
    @State private var resultMessage: String?
    @State private var isError = false
    @State private var showCelebration = false

    enum EditField {
        case target, duration
    }

    private var crownBinding: Binding<Double> {
        Binding(
            get: {
                guard !showConfirm else { return 0 }
                switch editingField {
                case .target: return customTarget
                case .duration: return customDuration
                }
            },
            set: { newValue in
                guard !showConfirm else { return }
                switch editingField {
                case .target: customTarget = newValue
                case .duration: customDuration = newValue
                }
            }
        )
    }

    private var crownRange: ClosedRange<Double> {
        guard !showConfirm else { return 0...1 }
        switch editingField {
        case .target: return 60...300
        case .duration: return 5...480
        }
    }

    private var crownStep: Double {
        switch editingField {
        case .target: return 5
        case .duration: return 5
        }
    }

    var body: some View {
        Group {
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
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        if showConfirm {
                            Text("\(pendingTarget) \(config.units == "mmol/L" ? "mmol/L" : "mg/dL") for \(pendingDuration)m")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(tempColor)

                            CrownConfirmView(label: "to set target") {
                                sendTempTarget()
                            }
                        } else {
                            Text("Custom Target")
                                .font(.system(size: 14, weight: .semibold))

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
                                        .foregroundColor(editingField == .target ? tempColor : .primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(editingField == .target ? tempColor.opacity(0.15) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

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
                                        .foregroundColor(editingField == .duration ? tempColor : .primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(editingField == .duration ? tempColor.opacity(0.15) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Text("Tap a field, then scroll crown")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            Button {
                                pendingTarget = Int(customTarget)
                                pendingDuration = Int(customDuration)
                                showConfirm = true
                            } label: {
                                Text("Set")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(tempColor)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .modifier(CrownRotationModifier(
            isActive: !showConfirm && resultMessage == nil,
            value: crownBinding,
            from: crownRange.lowerBound,
            through: crownRange.upperBound,
            by: crownStep,
            sensitivity: .medium
        ))
    }

    private func autoDismiss() {
        let delay = showCelebration ? CelebrationOverlay.displayDuration : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            dismiss()
        }
    }

    private func sendTempTarget() {
        WatchRemoteService.sendTempTarget(target: pendingTarget, duration: pendingDuration, config: config) { success, error in
            if success {
                resultMessage = "Target set!"
                showCelebration = CelebrationOverlay.shouldCelebrate()
                WatchRemoteService.postLocalNotification(
                    title: "Temp Target Set",
                    body: "\(pendingTarget) mg/dL for \(pendingDuration)m"
                )
                autoDismiss()
            } else {
                resultMessage = error ?? "Failed"
                isError = true
            }
        }
    }
}
