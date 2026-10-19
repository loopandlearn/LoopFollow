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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.requestState()
            }
        }
        .backgroundTask(.watchConnectivity) {
            await WatchSession.shared.waitForPendingContent()
        }
    }
}
