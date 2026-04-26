// LoopFollow
// RestartLiveActivityIntent.swift

#if !targetEnvironment(macCatalyst)
    import AppIntents
    import UIKit

    @available(iOS 16.4, *)
    struct RestartLiveActivityIntent: AppIntent, ForegroundContinuableIntent {
        static var title: LocalizedStringResource = "Restart Live Activity"
        static var description = IntentDescription("Starts or restarts the LoopFollow Live Activity.")

        func perform() async throws -> some IntentResult & ProvidesDialog {
            Storage.shared.laEnabled.value = true

            let keyId = Storage.shared.lfKeyId.value
            let apnsKey = Storage.shared.lfApnsKey.value

            if keyId.isEmpty || apnsKey.isEmpty {
                if let url = URL(string: "loopfollow://settings/live-activity") {
                    await MainActor.run { UIApplication.shared.open(url) }
                }
                return .result(dialog: "Please enter your APNs credentials in LoopFollow settings to use the Live Activity.")
            }

            if #available(iOS 26.0, *) {
                try await continueInForeground()
            }

            await MainActor.run { LiveActivityManager.shared.forceRestart() }

            return .result(dialog: "Live Activity restarted.")
        }
    }

    @available(iOS 16.4, *)
    struct LoopFollowAppShortcuts: AppShortcutsProvider {
        static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: RestartLiveActivityIntent(),
                phrases: ["Restart Live Activity in \(.applicationName)"],
                shortTitle: "Restart Live Activity",
                systemImageName: "dot.radiowaves.left.and.right"
            )
        }
    }
#endif
