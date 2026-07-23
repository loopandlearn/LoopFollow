// LoopFollow
// NotificationsStepView.swift

import SwiftUI

/// A short context screen ahead of the system notification prompt, following
/// Apple's pre-alert guidance. The system prompt is triggered from here — before
/// the final screen — so it never appears on top of "You're all set".
struct NotificationsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Stay informed")
                    .font(.title2.weight(.bold))

                Text("LoopFollow uses notifications to deliver your alarms — like low or high glucose, or a missed reading. Without them, alarms can't reach you when the app is in the background.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                Text("We'll ask iOS for permission next. You can change this any time in the Settings app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    guard !requesting else { return }
                    requesting = true
                    NotificationAuthorization.requestIfNeeded {
                        viewModel.advance()
                    }
                } label: {
                    Text("Enable Notifications")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(requesting)

                Button { viewModel.advance() } label: {
                    Text("Not now")
                        .font(.body.weight(.medium))
                }
                .disabled(requesting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
