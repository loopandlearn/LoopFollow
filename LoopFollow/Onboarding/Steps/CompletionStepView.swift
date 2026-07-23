// LoopFollow
// CompletionStepView.swift

import SwiftUI

struct CompletionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    /// A short tease of optional features worth discovering later — not part of
    /// setup, just a nudge toward a few things that are easy to miss.
    private struct Gem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let gems: [Gem] = [
        Gem(icon: "person.crop.square",
            title: "Contact image",
            detail: "Show your glucose on your Apple Watch face through a contact."),
        Gem(icon: "bell.badge",
            title: "Custom alarms",
            detail: "Build your own alarms beyond the recommended set."),
        Gem(icon: "dot.radiowaves.left.and.right",
            title: "Remote commands",
            detail: "Send carbs, boluses, and temp targets to Trio or Loop."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 84, weight: .semibold))
                    .foregroundStyle(.green.gradient)
                    .scaleEffect(animate || reduceMotion ? 1 : 0.6)
                    .opacity(animate || reduceMotion ? 1 : 0)

                Text("You're all set")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("You're ready to go. Adjust everything later from the Menu — and when you have a moment, these are worth a look:")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            gemsCard
                .padding(.top, 28)
                .padding(.horizontal, 24)

            Spacer(minLength: 24)

            Button { viewModel.finish() } label: {
                Text("Finish")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                animate = true
            }
        }
    }

    private var gemsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(gems) { gem in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: gem.icon)
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(gem.title)
                            .font(.subheadline.weight(.semibold))
                        Text(gem.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
