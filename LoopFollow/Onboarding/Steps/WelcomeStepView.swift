// LoopFollow
// WelcomeStepView.swift

import SwiftUI

struct WelcomeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                AnimatedLoopFollowLogo(size: 140)
                    .frame(height: 160)
                    .opacity(animate || reduceMotion ? 1 : 0)

                Text("Welcome to LoopFollow")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(viewModel.isAlreadyConfigured
                    ? "You're already set up. You can skip this guide, or walk through it to review your settings."
                    : "Let's get you connected to your data and set up a few recommended alarms. It only takes a few minutes.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                if viewModel.isAlreadyConfigured {
                    Button { viewModel.skip() } label: {
                        primaryLabel("Skip")
                    }
                    .buttonStyle(.borderedProminent)

                    Button { advance() } label: {
                        Text("Review setup anyway")
                            .font(.body.weight(.medium))
                    }
                } else {
                    Button { advance() } label: {
                        primaryLabel("Get Started")
                    }
                    .buttonStyle(.borderedProminent)

                    Button { viewModel.skip() } label: {
                        Text("Skip")
                            .font(.body.weight(.medium))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animate = true
            }
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private func advance() {
        if reduceMotion {
            viewModel.advance()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { viewModel.advance() }
        }
    }
}
