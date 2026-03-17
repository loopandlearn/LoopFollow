// LoopFollow
// BackgroundTaskAudio.swift

import AVFoundation

class BackgroundTask {
    // MARK: - Vars

    var player = AVAudioPlayer()
    var timer = Timer()

    private var retryCount = 0
    private let maxRetries = 3
    private var retryTimer: Timer?

    // MARK: - Methods

    func startBackgroundTask() {
        NotificationCenter.default.addObserver(self, selector: #selector(interruptedAudio), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        retryCount = 0
        playAudio()
    }

    func stopBackgroundTask() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        retryTimer?.invalidate()
        retryTimer = nil
        player.stop()
        LogManager.shared.log(category: .general, message: "Silent audio stopped", isDebug: true)
    }

    @objc fileprivate func interruptedAudio(_ notification: Notification) {
        LogManager.shared.log(category: .general, message: "Silent audio interrupted")
        guard notification.name == AVAudioSession.interruptionNotification,
              let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        if type == .ended {
            retryCount = 0
            playAudio()
        }
    }

    fileprivate func playAudio() {
        do {
            let bundle = Bundle.main.path(forResource: "blank", ofType: "wav")
            let alertSound = URL(fileURLWithPath: bundle!)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try player = AVAudioPlayer(contentsOf: alertSound)
            // Play audio forever by setting num of loops to -1
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            retryCount = 0
            LogManager.shared.log(category: .general, message: "Silent audio playing", isDebug: true)
        } catch {
            LogManager.shared.log(category: .general, message: "playAudio, error: \(error)")
            if retryCount < maxRetries {
                retryCount += 1
                LogManager.shared.log(category: .general, message: "playAudio retry \(retryCount)/\(maxRetries) in 2s")
                retryTimer?.invalidate()
                retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    self?.playAudio()
                }
            } else {
                LogManager.shared.log(category: .general, message: "playAudio failed after \(maxRetries) retries — posting BackgroundAudioFailed")
                NotificationCenter.default.post(name: .backgroundAudioFailed, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let backgroundAudioFailed = Notification.Name("BackgroundAudioFailed")
}
