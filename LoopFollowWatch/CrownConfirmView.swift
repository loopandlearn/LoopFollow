// LoopFollow
// CrownConfirmView.swift

import SwiftUI
import WatchKit

/// Reusable crown-rotation confirmation component.
/// User must TAP the wheel icon first, then scroll the Digital Crown through a full rotation to confirm.
struct CrownConfirmView: View {
    let label: String
    let onConfirm: () -> Void

    @State private var tapped = false
    @State private var progress: Double = 0
    @State private var confirmed = false
    @State private var resetTimer: Timer?

    // A full crown rotation is roughly 1.0 in value
    private let fullRotation: Double = 1.0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)

                // Progress ring (only visible after tap)
                if tapped {
                    Circle()
                        .trim(from: 0, to: min(progress / fullRotation, 1.0))
                        .stroke(
                            confirmed ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.15), value: progress)
                }

                // Center content
                if confirmed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "digitalcrown.arrow.clockwise")
                            .font(.system(size: tapped ? 20 : 24))
                            .foregroundColor(tapped ? .blue : .gray.opacity(0.5))
                            .rotationEffect(.degrees(tapped ? progress / fullRotation * 360 : 0))
                        if tapped {
                            Text("Scroll")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(width: 70, height: 70)
            .contentShape(Circle())
            .onTapGesture {
                if !tapped && !confirmed {
                    withAnimation { tapped = true }
                    WKInterfaceDevice.current().play(.click)
                }
            }

            // Instruction text
            if confirmed {
                Text("Sent!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
            } else if tapped {
                Text("Scroll crown \(label)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Tap wheel, then scroll \(label)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .focusable(tapped && !confirmed)
        .digitalCrownRotation(
            $progress,
            from: 0,
            through: fullRotation,
            by: 0.02,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: progress) { newValue in
            guard tapped else {
                // Reset if somehow triggered before tap
                progress = 0
                return
            }

            // Reset inactivity timer
            resetTimer?.invalidate()
            resetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                if !confirmed {
                    withAnimation { progress = 0 }
                }
            }

            // Check for completion
            if newValue >= fullRotation, !confirmed {
                withAnimation {
                    confirmed = true
                }
                WKInterfaceDevice.current().play(.success)
                onConfirm()
            }
        }
    }
}
