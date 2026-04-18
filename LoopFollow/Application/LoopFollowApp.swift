// LoopFollow
// LoopFollowApp.swift

import AVFoundation
import SwiftUI

@main
struct LoopFollowApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    private let synthesizer = AVSpeechSynthesizer()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    guard url.scheme == AppGroupID.urlScheme, url.host == "la-tap" else { return }
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .liveActivityDidForeground, object: nil)
                    }
                }
        }
    }
}
