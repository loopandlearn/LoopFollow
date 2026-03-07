// BackgroundTaskAudio.swift
// LoopFollow
// Philippe Achkar
// 2026-03-07

import AVFoundation

class BackgroundTask {

    // MARK: - Vars
    static let shared = BackgroundTask()
    var player = AVAudioPlayer()
    var timer = Timer()

    // MARK: - Methods
    func startBackgroundTask() {
        NotificationCenter.default.addObserver(self, selector: #selector(interruptedAudio), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        playAudio()
    }

    func stopBackgroundTask() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        player.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            LogManager.shared.log(category: .general, message: "Silent audio stopped", isDebug: true)
        } catch {
            LogManager.shared.log(category: .general, message: "Silent audio stop failed: \(error)", isDebug: true)
        }
    }

    @objc private func interruptedAudio(_ notification: Notification) {
        LogManager.shared.log(category: .general, message: "Silent audio interrupted")
        if notification.name == AVAudioSession.interruptionNotification, notification.userInfo != nil {
            var info = notification.userInfo!
            var intValue = 0
            (info[AVAudioSessionInterruptionTypeKey]! as AnyObject).getValue(&intValue)
            if intValue == 1 { playAudio() }
        }
    }

    private func playAudio() {
        do {
            let bundle = Bundle.main.path(forResource: "blank", ofType: "wav")
            let alertSound = URL(fileURLWithPath: bundle!)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try player = AVAudioPlayer(contentsOf: alertSound)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            LogManager.shared.log(category: .general, message: "Silent audio playing", isDebug: true)
        } catch {
            LogManager.shared.log(category: .general, message: "playAudio, error: \(error)")
        }
    }
}
