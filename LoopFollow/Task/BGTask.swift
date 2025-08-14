// LoopFollow
// BGTask.swift

import Foundation

extension MainViewController {
    func scheduleBGTask(initialDelay: TimeInterval = 2) {
        let firstRun = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .fetchBG, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.bgTaskAction()
        }
    }

    func bgTaskAction() {
        // If anything goes wrong, try again in 60 seconds.
        TaskScheduler.shared.rescheduleTask(
            id: .fetchBG,
            to: Date().addingTimeInterval(60)
        )

        // If no Dexcom credentials and no Nightscout, schedule a retry in 60 seconds.
        if Storage.shared.shareUserName.value == "",
           Storage.shared.sharePassword.value == "",
           !IsNightscoutEnabled()
        {
            return
        }

        // If Dexcom credentials exist, fetch from DexShare
        if Storage.shared.shareUserName.value != "",
           Storage.shared.sharePassword.value != ""
        {
            webLoadDexShare()
        } else {
            webLoadNSBGData()
        }
    }
}
