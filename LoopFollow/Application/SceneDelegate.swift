// LoopFollow
// SceneDelegate.swift

import AVFoundation
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let synthesizer = AVSpeechSynthesizer()

    /// One-shot guard so the consent prompt is only attempted once per
    /// process lifetime even if the scene activates repeatedly.
    private var consentPromptShownThisProcess = false

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }

        // get the tabBar
        guard let tabBarController = window?.rootViewController as? UITabBarController,
              let viewControllers = tabBarController.viewControllers
        else {
            return
        }
    }

    func sceneDidDisconnect(_: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        runTelemetryFirstForegroundHook()
    }

    /// Presents the one-time consent sheet on first foreground. Sending is
    /// handled by AppDelegate at launch and by TaskScheduler thereafter —
    /// firing maybeSend here would duplicate the launch-time send.
    private func runTelemetryFirstForegroundHook() {
        if !Storage.shared.telemetryConsentDecisionMade.value,
           !consentPromptShownThisProcess
        {
            consentPromptShownThisProcess = true
            presentTelemetryConsentSheet()
        }
    }

    private func presentTelemetryConsentSheet() {
        guard let root = window?.rootViewController else { return }
        // Find the topmost presented controller so we don't try to present
        // over a sheet that's already up.
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        let host = UIHostingController(rootView: TelemetryConsentView())
        host.isModalInPresentation = true // user must explicitly choose
        // Defer to the next runloop so view hierarchy is settled when the
        // scene first becomes active on a fresh install.
        DispatchQueue.main.async {
            top.present(host, animated: true)
        }
    }

    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard URLContexts.contains(where: { $0.url.scheme == AppGroupID.urlScheme && $0.url.host == "la-tap" }) else { return }
        // scene(_:openURLContexts:) fires after sceneDidBecomeActive when the app
        // foregrounds from background. Post on the next run loop so the view
        // hierarchy (including any presented modals) is fully settled.
        #if !targetEnvironment(macCatalyst)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .liveActivityDidForeground, object: nil)
            }
        #endif
    }

    func sceneWillResignActive(_: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }

    /// Handle the UIApplicationShortcutItem when the user taps on the Home Screen Quick Action. This function toggles the "Speak BG" setting in UserDefaultsRepository, speaks the current state (on/off) using AVSpeechSynthesizer, and updates the Quick Action appearance.
    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let expectedType = bundleIdentifier + ".toggleSpeakBG"
            if shortcutItem.type == expectedType {
                Storage.shared.speakBG.value.toggle()
                let message = Storage.shared.speakBG.value ? "BG Speak is now on" : "BG Speak is now off"
                let utterance = AVSpeechUtterance(string: message)
                synthesizer.speak(utterance)
            }
        }
    }

    /// The following method is called when the user taps on the Home Screen Quick Action
    func windowScene(_: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler _: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
    }
}
