// LoopFollow
// LoopFollowApp.swift

import SwiftUI

@main
struct LoopFollowApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    guard url.scheme == AppGroupID.urlScheme, url.host == "la-tap" else { return }
                    #if !targetEnvironment(macCatalyst)
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .liveActivityDidForeground, object: nil)
                        }
                    #endif
                }
        }
    }
}
