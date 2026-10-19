// LoopFollow
// LoopFollowWatchApp.swift

import SwiftUI

@main
struct LoopFollowWatchApp: App {
    @StateObject private var session = WatchSession.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchSession.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    session.requestState()
                    session.scheduleBackgroundRefresh()
                    // While open, check every minute whether the watch has to fetch on its own.
                    while !Task.isCancelled {
                        await session.refreshIfNeeded()
                        try? await Task.sleep(nanoseconds: 60_000_000_000)
                    }
                }
        }
        .backgroundTask(.watchConnectivity) {
            await WatchSession.shared.waitForPendingContent()
        }
        .backgroundTask(.appRefresh(WatchSession.backgroundRefreshID)) {
            await WatchSession.shared.refreshIfNeeded()
            await WatchSession.shared.scheduleBackgroundRefresh()
        }
    }
}
