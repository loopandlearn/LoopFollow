// LoopFollow
// CommandConfirmView.swift

import LocalAuthentication
import SwiftUI
import WatchKit

/// Final step for every command: shows what will be sent, asks for confirmation
/// and shows the phone's reply. Insulin needs a full turn of the Digital Crown
/// and an unlocked watch on the wrist. A sent command is not yet delivered:
/// Loop or Trio confirms it later with a notification.
struct CommandConfirmView: View {
    let request: CommandRequest

    @EnvironmentObject private var session: WatchSession
    @EnvironmentObject private var navigator: WatchNavigator
    @Environment(\.dismiss) private var dismiss

    /// How long the "sent" screen stays before returning to the glucose page.
    private let sentDisplayTime: TimeInterval = 3

    @State private var phase: Phase = .confirm
    @State private var crownProgress = 0.0
    @State private var lastCrownChange = Date()
    @FocusState private var crownFocused: Bool

    enum Phase: Equatable {
        case confirm
        case sending
        case done(success: Bool, message: String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                switch phase {
                case .confirm:
                    summary
                    if request.deliversInsulin {
                        crownConfirm
                    } else {
                        Button("Send") { Task { await send() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                    }
                case .sending:
                    ProgressView()
                    Text("Sending…")
                        .foregroundStyle(.secondary)
                case let .done(success, message):
                    if success {
                        Image(systemName: "paperplane.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        Text("Sent")
                            .font(.headline)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                        Button("OK") { dismiss() }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(request.title)
        .navigationBarBackButtonHidden(phase != .confirm)
    }

    private var summary: some View {
        VStack(spacing: 2) {
            ForEach(request.lines, id: \.self) { line in
                Text(line)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var crownConfirm: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: crownProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "digitalcrown.arrow.clockwise")
                    .font(.title3)
            }
            .frame(width: 56, height: 56)
            Text("Turn the Digital Crown to confirm")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($crownProgress, from: 0, through: 1, by: 0.02, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear { crownFocused = true }
        .onChange(of: crownProgress) { _, value in
            lastCrownChange = Date()
            if value >= 1 {
                WKInterfaceDevice.current().play(.success)
                Task { await authenticateAndSend() }
            } else {
                resetCrownIfIdle()
            }
        }
    }

    /// Partial turns reset after a pause, so a bump of the crown never adds up to a confirmation.
    private func resetCrownIfIdle() {
        let changedAt = lastCrownChange
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if phase == .confirm, lastCrownChange == changedAt, crownProgress < 1 {
                withAnimation { crownProgress = 0 }
            }
        }
    }

    private func authenticateAndSend() async {
        switch await Self.authenticate() {
        case .success:
            await send()
        case let .failure(message):
            crownProgress = 0
            phase = .done(success: false, message: message)
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func send() async {
        phase = .sending
        let reply = await session.send(request.action)
        phase = .done(success: reply.success, message: reply.message)
        WKInterfaceDevice.current().play(reply.success ? .success : .failure)
        if reply.success {
            try? await Task.sleep(nanoseconds: UInt64(sentDisplayTime * 1_000_000_000))
            navigator.popToRoot()
        }
    }

    private enum AuthOutcome {
        case success
        case failure(String)
    }

    /// Requires a passcode-protected watch that is unlocked on the wrist.
    private static func authenticate() async -> AuthOutcome {
        #if targetEnvironment(simulator)
            return .success
        #else
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithWristDetection, error: &error) else {
                return .failure("Insulin can only be sent from a watch with a passcode and Wrist Detection turned on.")
            }
            do {
                let ok = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithWristDetection, localizedReason: "Confirm to send insulin")
                return ok ? .success : .failure("Authentication failed.")
            } catch {
                return .failure("Authentication failed.")
            }
        #endif
    }
}
