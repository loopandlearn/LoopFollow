// LoopFollow
// BackgroundRefreshManager.swift

import BackgroundTasks
import UIKit

class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    private init() {}

    private let taskIdentifier = "\(Bundle.main.bundleIdentifier ?? "com.loopfollow").audiorefresh"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleRefreshTask(refreshTask)
        }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        LogManager.shared.log(category: .taskScheduler, message: "BGAppRefreshTask fired")

        // Guard against double setTaskCompleted if expiration fires while the
        // main-queue block is in-flight (Apple documents this as a programming error).
        var completed = false

        task.expirationHandler = {
            guard !completed else { return }
            completed = true
            LogManager.shared.log(category: .taskScheduler, message: "BGAppRefreshTask expired")
            task.setTaskCompleted(success: false)
            self.scheduleRefresh()
        }

        DispatchQueue.main.async {
            guard !completed else { return }
            completed = true
            if let mainVC = self.getMainViewController() {
                if !mainVC.backgroundTask.player.isPlaying {
                    LogManager.shared.log(category: .taskScheduler, message: "audio dead, attempting restart")
                    mainVC.backgroundTask.stopBackgroundTask()
                    mainVC.backgroundTask.startBackgroundTask()
                    LogManager.shared.log(category: .taskScheduler, message: "audio restart initiated")
                } else {
                    LogManager.shared.log(category: .taskScheduler, message: "audio alive, no action needed", isDebug: true)
                }
            }
            self.scheduleRefresh()
            task.setTaskCompleted(success: true)
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            LogManager.shared.log(category: .taskScheduler, message: "Failed to schedule BGAppRefreshTask: \(error)")
        }
    }

    private func getMainViewController() -> MainViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController
        else {
            return nil
        }

        if let mainVC = rootVC as? MainViewController {
            return mainVC
        }

        if let navVC = rootVC as? UINavigationController,
           let mainVC = navVC.viewControllers.first as? MainViewController
        {
            return mainVC
        }

        if let tabVC = rootVC as? UITabBarController {
            for vc in tabVC.viewControllers ?? [] {
                if let mainVC = vc as? MainViewController {
                    return mainVC
                }
                if let navVC = vc as? UINavigationController,
                   let mainVC = navVC.viewControllers.first as? MainViewController
                {
                    return mainVC
                }
            }
        }

        return nil
    }
}
