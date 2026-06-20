// LoopFollow
// OverviewStepView.swift

import SwiftUI

/// A quick map of what the rest of setup covers, so the user knows what to
/// expect. The list reflects the phases that will actually run — a returning
/// user who's already connected won't see "Connect your data" — and collapses to
/// a short "you're all set" when there's nothing left to configure.
struct OverviewStepView: View {
    @ObservedObject var onboarding: OnboardingViewModel

    private struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    /// The overview rows, derived from the phases that will actually run.
    private var items: [Item] {
        let steps = onboarding.activeSteps
        var result: [Item] = []
        if steps.contains(.connect) {
            result.append(Item(icon: "antenna.radiowaves.left.and.right",
                               title: "Connect your data",
                               detail: "Link a Nightscout site or a Dexcom Share account."))
        }
        if steps.contains(.units) {
            result.append(Item(icon: "ruler",
                               title: "Units & metrics",
                               detail: "Choose how glucose and statistics are shown."))
        }
        if steps.contains(.alarms) {
            result.append(Item(icon: "bell.badge.fill",
                               title: "Recommended alarms",
                               detail: "Turn on a few useful alarms with sensible defaults."))
        }
        if steps.contains(.tabOrder) {
            result.append(Item(icon: "square.grid.2x2",
                               title: "Finish up",
                               detail: "Arrange your tabs and set notification preferences."))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if onboarding.hasNothingToSetUp {
                allSet
            } else {
                checklist
            }
            footer
        }
    }

    // MARK: - Content

    private var checklist: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingStepHeader(
                    systemImage: "list.bullet.rectangle",
                    title: "Here's what we'll do",
                    subtitle: "A quick, straightforward setup — about 5 minutes. You can change anything later in Settings."
                )
                .padding(.horizontal)

                VStack(spacing: 14) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }

    private var allSet: some View {
        ScrollView {
            OnboardingStepHeader(
                systemImage: "checkmark.circle",
                title: "You're all set",
                subtitle: "Your data source is connected and your alarms are in place — there's nothing to set up here. You can fine-tune anything later in Settings."
            )
            .padding(.horizontal)
            .padding(.top, 24)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        OnboardingNavFooter(
            continueTitle: onboarding.hasNothingToSetUp ? "Done" : "Continue",
            continueEnabled: true,
            showBack: onboarding.canGoBack,
            onBack: { onboarding.goBack() },
            onContinue: {
                if onboarding.hasNothingToSetUp {
                    onboarding.finish()
                } else {
                    onboarding.advance()
                }
            }
        )
    }
}
