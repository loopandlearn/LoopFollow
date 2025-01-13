//
//  SceneDelegate.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/1/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import AVFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let synthesizer = AVSpeechSynthesizer()

    let appStateController = AppStateController()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
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
                  
         // set the main controllers' connection to the app sate
         // other controllers that need to know app state are setup programatically
         for i in 0..<viewControllers.count {
            if let vc = viewControllers[i] as? MainViewController {
               vc.appStateController = appStateController
            }
            if let vc = viewControllers[i] as? NightscoutViewController {
               vc.appStateController = appStateController
            }
            if let vc = viewControllers[i] as? SettingsViewController {
               vc.appStateController = appStateController
            }
            if let vc = viewControllers[i] as? AlarmViewController {
               vc.appStateController = appStateController
            }
            if let vc = viewControllers[i] as? SnoozeViewController {
               vc.appStateController = appStateController
            }
            if let vc = viewControllers[i] as? debugViewController {
               vc.appStateController = appStateController
            }
         }

        // Register the SceneDelegate as an observer for the "toggleSpeakBG" notification, which will be triggered when the user toggles the "Speak BG" feature in General Settings. This helps ensure that the Quick Action is updated according to the current setting.
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleSpeakBGEvent), name: NSNotification.Name("toggleSpeakBG"), object: nil)
        updateQuickActions()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("toggleSpeakBG"), object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }

    // Update the Home Screen Quick Action for toggling the "Speak BG" feature based on the current setting in UserDefaultsRepository. This function uses UIApplicationShortcutItem to create a 3D touch action for controlling the feature.
    func updateQuickActions() {
        let iconName = UserDefaultsRepository.speakBG.value ? "pause.circle.fill" : "play.circle.fill"
        let iconTemplate = UIApplicationShortcutIcon(systemImageName: iconName)

        let shortcut = UIApplicationShortcutItem(type: Bundle.main.bundleIdentifier! + ".toggleSpeakBG",
                                                 localizedTitle: "Speak BG",
                                                 localizedSubtitle: nil,
                                                 icon: iconTemplate,
                                                 userInfo: nil)
        UIApplication.shared.shortcutItems = [shortcut]
    }


    // Handle the UIApplicationShortcutItem when the user taps on the Home Screen Quick Action. This function toggles the "Speak BG" setting in UserDefaultsRepository, speaks the current state (on/off) using AVSpeechSynthesizer, and updates the Quick Action appearance.
    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let expectedType = bundleIdentifier + ".toggleSpeakBG"
            if shortcutItem.type == expectedType {
                UserDefaultsRepository.speakBG.value.toggle()
                let message = UserDefaultsRepository.speakBG.value ? "BG Speak is now on" : "BG Speak is now off"
                let utterance = AVSpeechUtterance(string: message)
                synthesizer.speak(utterance)
                updateQuickActions()
            }
        }
    }

    // The following method is called when the user taps on the Home Screen Quick Action
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
    }

    @objc func handleToggleSpeakBGEvent() {
        updateQuickActions()
    }
}
