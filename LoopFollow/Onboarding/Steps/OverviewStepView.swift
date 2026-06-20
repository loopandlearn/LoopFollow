// LoopFollow
// OverviewStepView.swift

import SwiftUI

/// A quick map of what the rest of setup covers, so the user knows what to
/// expect and roughly how long it takes.
struct OverviewStepView: View {
    private struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let items: [Item] = [
        Item(icon: "antenna.radiowaves.left.and.right",
             title: "Connect your data",
             detail: "Link a Nightscout site or a Dexcom Share account."),
        Item(icon: "ruler",
             title: "Units & metrics",
             detail: "Choose how glucose and statistics are shown."),
        Item(icon: "bell.badge.fill",
             title: "Recommended alarms",
             detail: "Turn on a few useful alarms with sensible defaults."),
        Item(icon: "square.grid.2x2",
             title: "Finish up",
             detail: "Arrange your tabs and set notification preferences."),
    ]

    var body: some View {
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
}
