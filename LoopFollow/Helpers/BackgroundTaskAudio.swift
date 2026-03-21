// LoopFollow
// BackgroundTaskAudio.swift

import AVFoundation

class BackgroundTask {
    // MARK: - Vars

    var player = AVAudioPlayer()

    private var retryCount = 0
    private let maxRetries = 3

    // MARK: - Methods

    func startBackgroundTask() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interruptedAudio), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        retryCount = 0
        playAudio()
    }

    func stopBackgroundTask() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        player.stop()
        LogManager.shared.log(category: .general, message: "Silent audio stopped", isDebug: true)
    }

    @objc private func interruptedAudio(_ notification: Notification) {
        guard notification.name == AVAudioSession.interruptionNotification,
              let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            LogManager.shared.log(category: .general, message: "[LA] Silent audio session interrupted (began)")

        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if !options.contains(.shouldResume) {
                    LogManager.shared.log(category: .general, message: "[LA] Silent audio interruption ended — shouldResume not set, attempting restart anyway")
                }
            }
            LogManager.shared.log(category: .general, message: "[LA] Silent audio interruption ended — scheduling restart in 0.5s")
            retryCount = 0
            // Brief delay to let the interrupting app (e.g. Clock alarm) fully release the audio
            // session before we attempt to reactivate. Without this, setActive(true) races with
            // the alarm and fails with AVAudioSession.ErrorCode.cannotInterruptOthers (560557684).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.playAudio()
            }

        @unknown default:
            break
        }
    }

    private func playAudio() {
        let attemptDesc = retryCount == 0 ? "initial attempt" : "retry \(retryCount)/\(maxRetries)"
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
            LogManager.shared.log(category: .general, message: "Silent audio playing (\(attemptDesc))", isDebug: true)
        } catch {
            LogManager.shared.log(category: .general, message: "playAudio failed (\(attemptDesc)), error: \(error)")
            if retryCount < maxRetries {
                retryCount += 1
                LogManager.shared.log(category: .general, message: "playAudio scheduling retry \(retryCount)/\(maxRetries) in 2s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
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
