// LoopFollow
// AlarmSound.swift

import AVFoundation
import Foundation
import MediaPlayer
import UIKit

/*
 * Class that handles the playing and the volume of the alarm sound.
 */
class AlarmSound {
    static var isPlaying: Bool {
        return audioPlayer?.isPlaying == true
    }

    static var isMuted: Bool {
        return muted
    }

    static var whichAlarm: String = "none"
    static var soundFile = "Indeed"
    static var isTesting: Bool = false

    fileprivate static var systemOutputVolumeBeforeOverride: Float?

    fileprivate static var soundURL = Bundle.main.url(forResource: "Indeed", withExtension: "caf")!
    fileprivate static var audioPlayer: AVAudioPlayer?
    fileprivate static let audioPlayerDelegate = AudioPlayerDelegate()

    fileprivate static var muted = false

    fileprivate static var alarmPlayingForTimer = Timer()
    fileprivate static let alarmPlayingForInterval = 290

    fileprivate func startAlarmPlayingForTimer(time: TimeInterval) {
        AlarmSound.alarmPlayingForTimer = Timer.scheduledTimer(timeInterval: time,
                                                               target: self,
                                                               selector: #selector(AlarmSound.alarmPlayingForTimerDidEnd(_:)),
                                                               userInfo: nil,
                                                               repeats: true)
    }

    @objc func alarmPlayingForTimerDidEnd(_: Timer) {
        if !AlarmSound.isPlaying { return }
        AlarmSound.stop()
    }

    /*
     * Sets the audio volume to 0.
     */
    static func muteVolume() {
        audioPlayer?.volume = 0
        muted = true
        restoreSystemOutputVolume()
    }

    static func setSoundFile(str: String) {
        soundURL = Bundle.main.url(forResource: str, withExtension: "caf")!
    }

    /*
     * Sets the volume of the alarm back to the volume before it has been muted.
     */
    static func unmuteVolume() {
        audioPlayer?.volume = 1.0
        muted = false
    }

    static func stop() {
        Observable.shared.alarmSoundPlaying.value = false

        audioPlayer?.stop()
        audioPlayer = nil

        restoreSystemOutputVolume()
    }

    static func playTest() {
        guard !isPlaying else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer!.delegate = audioPlayerDelegate

            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer?.numberOfLoops = 0

            if !audioPlayer!.prepareToPlay() {
                LogManager.shared.log(category: .alarm, message: "AlarmSound - audio player failed preparing to play")
            }

            if audioPlayer!.play() {
                if !isPlaying {
                    LogManager.shared.log(category: .alarm, message: "AlarmSound - not playing after calling play")
                    LogManager.shared.log(category: .alarm, message: "AlarmSound - rate value: \(audioPlayer!.rate)")
                }
            } else {
                LogManager.shared.log(category: .alarm, message: "AlarmSound - audio player failed to play")
            }

        } catch {
            LogManager.shared.log(category: .alarm, message: "AlarmSound - unable to play sound; error: \(error)")
        }
    }

    static func play(repeating: Bool) {
        guard !isPlaying else {
            return
        }

        enableAudio()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer!.delegate = audioPlayerDelegate

            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer!.numberOfLoops = repeating ? -1 : 0

            // Store existing volume
            if systemOutputVolumeBeforeOverride == nil {
                systemOutputVolumeBeforeOverride = AVAudioSession.sharedInstance().outputVolume
            }

            if !audioPlayer!.prepareToPlay() {
                LogManager.shared.log(category: .alarm, message: "AlarmSound - audio player failed preparing to play")
            }

            if audioPlayer!.play() {
                if !isPlaying {
                    LogManager.shared.log(category: .alarm, message: "AlarmSound - not playing after calling play")
                    LogManager.shared.log(category: .alarm, message: "AlarmSound - rate value: \(audioPlayer!.rate)")
                } else {
                    Observable.shared.alarmSoundPlaying.value = true
                }
            } else {
                LogManager.shared.log(category: .alarm, message: "AlarmSound - audio player failed to play")
            }

            if Storage.shared.alarmConfiguration.value.overrideSystemOutputVolume {
                MPVolumeView.setVolume(Storage.shared.alarmConfiguration.value.forcedOutputVolume)
            }
        } catch {
            LogManager.shared.log(category: .alarm, message: "AlarmSound - unable to play sound; error: \(error)")
        }
    }

    static func playTerminated() {
        guard !isPlaying else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer!.delegate = audioPlayerDelegate

            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)

            // Play endless loops
            audioPlayer!.numberOfLoops = 2

            // Store existing volume
            if systemOutputVolumeBeforeOverride == nil {
                systemOutputVolumeBeforeOverride = AVAudioSession.sharedInstance().outputVolume
            }

            if !audioPlayer!.prepareToPlay() {
                LogManager.shared.log(category: .alarm, message: "Terminate AlarmSound - audio player failed preparing to play")
            }

            if audioPlayer!.play() {
                if !isPlaying {
                    LogManager.shared.log(category: .alarm, message: "Terminate AlarmSound - not playing after calling play")
                    LogManager.shared.log(category: .alarm, message: "Terminate AlarmSound - rate value: \(audioPlayer!.rate)")
                }
            } else {
                LogManager.shared.log(category: .alarm, message: "Terminate AlarmSound - audio player failed to play")
            }

            MPVolumeView.setVolume(1.0)

        } catch {
            LogManager.shared.log(category: .alarm, message: "Terminate AlarmSound - unable to play sound; error: \(error)")
        }
    }

    fileprivate static func restoreSystemOutputVolume() {
        guard Storage.shared.alarmConfiguration.value.overrideSystemOutputVolume else {
            return
        }

        // cancel any volume change observations
        // self.volumeChangeDetector.isActive = false

        // restore system output volume with its value before overriding it
        if let volumeBeforeOverride = systemOutputVolumeBeforeOverride {
            MPVolumeView.setVolume(volumeBeforeOverride)
        }

        systemOutputVolumeBeforeOverride = nil
    }

    fileprivate static func enableAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            LogManager.shared.log(category: .alarm, message: "Enable audio error: \(error)")
        }
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    /* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. This method is NOT called if the player is stopped due to an interruption. */
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
        LogManager.shared.log(category: .alarm, message: "AlarmRule - audioPlayerDidFinishPlaying (\(flag))", isDebug: true)
        Observable.shared.alarmSoundPlaying.value = false
    }

    /* if an error occurs while decoding it will be reported to the delegate. */
    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
        if let error = error {
            LogManager.shared.log(category: .alarm, message: "AlarmRule - audioPlayerDecodeErrorDidOccur: \(error)")
        } else {
            LogManager.shared.log(category: .alarm, message: "AlarmRule - audioPlayerDecodeErrorDidOccur")
        }
    }

    /* AVAudioPlayer INTERRUPTION NOTIFICATIONS ARE DEPRECATED - Use AVAudioSession instead. */

    /* audioPlayerBeginInterruption: is called when the audio session has been interrupted while the player was playing. The player will have been paused. */
    func audioPlayerBeginInterruption(_: AVAudioPlayer) {
        LogManager.shared.log(category: .alarm, message: "AlarmRule - audioPlayerBeginInterruption")
        Observable.shared.alarmSoundPlaying.value = false
    }

    /* audioPlayerEndInterruption:withOptions: is called when the audio session interruption has ended and this player had been interrupted while playing. */
    /* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
    func audioPlayerEndInterruption(_: AVAudioPlayer, withOptions flags: Int) {
        LogManager.shared.log(category: .alarm, message: "AlarmRule - audioPlayerEndInterruption withOptions: \(flags)")
        Observable.shared.alarmSoundPlaying.value = false
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        // Need to use the MPVolumeView in order to change volume, but don't care about UI set so frame to .zero
        let volumeView = MPVolumeView(frame: .zero)
        // Search for the slider
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        // Update the slider value with the desired volume.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = volume
        }
        // Optional - Remove the HUD
        if let app = UIApplication.shared.delegate as? AppDelegate, let window = app.window {
            volumeView.alpha = 0.000001
            window.addSubview(volumeView)
        }
    }
}
