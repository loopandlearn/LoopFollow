// LoopFollow
// RemoteControlView.swift

import SwiftUI

private let tempColor = Color(red: 0.2, green: 0.9, blue: 0.1)

struct RemoteControlView: View {
    let config: WatchConfig
    @ObservedObject var bgFetcher: BGFetcher
    @ObservedObject var router: NavigationRouter

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: 8) {
                Button {
                    router.activeDestination = .bolus
                } label: {
                    RemoteTile(icon: "drop.fill", label: "Bolus", color: .blue)
                }
                .buttonStyle(.plain)

                Button {
                    router.activeDestination = .meal
                } label: {
                    RemoteTile(icon: "fork.knife", label: "Meal", color: .yellow)
                }
                .buttonStyle(.plain)

                Button {
                    router.activeDestination = .override
                } label: {
                    RemoteTile(icon: "bolt.fill", label: "Override", color: .purple)
                }
                .buttonStyle(.plain)

                Button {
                    router.activeDestination = .tempTarget
                } label: {
                    RemoteTile(icon: "target", label: "Temp", color: tempColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .navigationDestination(item: $router.activeDestination) { destination in
                switch destination {
                case .bolus:
                    WatchBolusView(
                        config: config,
                        bgFetcher: bgFetcher,
                        popToRoot: { router.activeDestination = nil }
                    )
                case .meal:
                    WatchMealView(
                        config: config,
                        bgFetcher: bgFetcher,
                        popToRoot: { router.activeDestination = nil }
                    )
                case .override:
                    WatchOverrideView(config: config, bgFetcher: bgFetcher)
                case .tempTarget:
                    WatchTempTargetView(config: config, bgFetcher: bgFetcher)
                }
            }
        }
    }
}

private struct RemoteTile: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            ZStack {
                // Base gradient — lighter top, darker bottom for 3D depth
                LinearGradient(
                    colors: [color, color.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Top highlight for raised look
                VStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 14)
                    Spacer()
                }
            }
        )
        .cornerRadius(6)
    }
}
