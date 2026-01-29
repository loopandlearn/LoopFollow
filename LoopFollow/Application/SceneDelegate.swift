// LoopFollow
// SceneDelegate.swift

import AVFoundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let synthesizer = AVSpeechSynthesizer()

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
