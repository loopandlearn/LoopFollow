// LoopFollow
// RemoteControlView.swift

import SwiftUI

struct RemoteControlView: View {
    let config: WatchConfig
    @ObservedObject var bgFetcher: BGFetcher

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: 8) {
                NavigationLink {
                    WatchBolusView(config: config)
                } label: {
                    RemoteTile(icon: "💧", label: "Bolus", color: .blue)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WatchMealView(config: config)
                } label: {
                    RemoteTile(icon: "🍽️", label: "Meal", color: .yellow)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WatchOverrideView(config: config, bgFetcher: bgFetcher)
                } label: {
                    RemoteTile(icon: "⚡", label: "Override", color: .purple)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WatchTempTargetView(config: config)
                } label: {
                    RemoteTile(icon: "🎯", label: "Temp", color: .pink)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }
}

private struct RemoteTile: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 30))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(color.opacity(0.3))
        .cornerRadius(12)
    }
}
