//
//  AlarmSound.swift
//  scoutwatch
//
//  Created by Dirk Hermanns on 03.01.16.
//  Copyright © 2016 private. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit

/*
 * Class that handles the playing and the volume of the alarm sound.
 */
class AlarmSound {
    
    static var isPlaying: Bool {
        return self.audioPlayer?.isPlaying == true
    }
    
    static var isMuted: Bool {
        return self.muted
    }
    static var whichAlarm: String = "none"
    static var soundFile = "Indeed"
    static var isTesting: Bool = false
    
    //static let volumeChangeDetector = VolumeChangeDetector()
    
    static let vibrate = UserDefaultsRepository.vibrate
    
    fileprivate static var systemOutputVolumeBeforeOverride: Float?
    
    fileprivate static var playingTimer: Timer?
    
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
    
    @objc func alarmPlayingForTimerDidEnd(_ timer:Timer) {
        if !AlarmSound.isPlaying { return }
        AlarmSound.stop()
    }
    
    /*
     * Sets the audio volume to 0.
     */
    static func muteVolume() {
        self.audioPlayer?.volume = 0
        self.muted = true
        self.restoreSystemOutputVolume()
    }
    
    static func setSoundFile(str: String) {
        self.soundURL = Bundle.main.url(forResource: str, withExtension: "caf")!
    }
    
    /*
     * Sets the volume of the alarm back to the volume before it has been muted.
     */
    static func unmuteVolume() {
        if UserDefaultsRepository.fadeInTimeInterval.value > 0 {
            self.audioPlayer?.setVolume(1.0, fadeDuration: UserDefaultsRepository.fadeInTimeInterval.value)
        } else {
            self.audioPlayer?.volume = 1.0
        }
        self.muted = false
    }
    
    static func stop() {
        self.playingTimer?.invalidate()
        self.playingTimer = nil
        
        self.audioPlayer?.stop()
        self.audioPlayer = nil
        
        self.restoreSystemOutputVolume()
    }
    
    static func playTest() {
        
        guard !self.isPlaying else {
            return
        }
        
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: self.soundURL)
            self.audioPlayer!.delegate = self.audioPlayerDelegate
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)
            
            self.audioPlayer?.numberOfLoops = 0
            
            // init volume before start playing (mute if fade-in)
            
            //self.audioPlayer!.volume = (self.muted || (UserDefaultsRepository.fadeInTimeInterval.value > 0)) ? 0.0 : 1.0
            
            if !self.audioPlayer!.prepareToPlay() {
                NSLog("AlarmSound - audio player failed preparing to play")
            }
            
            if self.audioPlayer!.play() {
                if !self.isPlaying {
                    NSLog("AlarmSound - not playing after calling play")
                    NSLog("AlarmSound - rate value: \(self.audioPlayer!.rate)")
                }
            } else {
                NSLog("AlarmSound - audio player failed to play")
            }
            
            
        } catch let error {
            NSLog("AlarmSound - unable to play sound; error: \(error)")
        }
    }
    
    
    static func play(overrideVolume: Bool, numLoops: Int) {
        guard !self.isPlaying else {
            return
        }

        enableAudio()

        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: self.soundURL)
            self.audioPlayer!.delegate = self.audioPlayerDelegate
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Play endless loops
            self.audioPlayer!.numberOfLoops = numLoops
            
            // Store existing volume
            if self.systemOutputVolumeBeforeOverride == nil {
                self.systemOutputVolumeBeforeOverride = AVAudioSession.sharedInstance().outputVolume
            }
            
            // init volume before start playing (mute if fade-in)
            //self.audioPlayer!.volume = (self.muted || (UserDefaultsRepository.fadeInTimeInterval.value > 0)) ? 0.0 : 1.0
            
            if !self.audioPlayer!.prepareToPlay() {
                NSLog("AlarmSound - audio player failed preparing to play")
            }
            
            if self.audioPlayer!.play() {
                if !self.isPlaying {
                    NSLog("AlarmSound - not playing after calling play")
                    NSLog("AlarmSound - rate value: \(self.audioPlayer!.rate)")
                }
            } else {
                NSLog("AlarmSound - audio player failed to play")
            }
            
            
            // do fade-in
            //if !self.muted && (UserDefaultsRepository.fadeInTimeInterval.value > 0) {
            //    self.audioPlayer!.setVolume(1.0, fadeDuration: UserDefaultsRepository.fadeInTimeInterval.value)
            //}
            
            if overrideVolume {
                MPVolumeView.setVolume(UserDefaultsRepository.forcedOutputVolume.value)
            }
            
            
        } catch let error {
            NSLog("AlarmSound - unable to play sound; error: \(error)")
        }
    }
    
    static func playTerminated() {
        
        guard !self.isPlaying else {
            return
        }
        
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: self.soundURL)
            self.audioPlayer!.delegate = self.audioPlayerDelegate
            
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)))
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Play endless loops
            self.audioPlayer!.numberOfLoops = 2
            
            // Store existing volume
            if self.systemOutputVolumeBeforeOverride == nil {
                self.systemOutputVolumeBeforeOverride = AVAudioSession.sharedInstance().outputVolume
            }
            
            
            if !self.audioPlayer!.prepareToPlay() {
                NSLog("Terminate AlarmSound - audio player failed preparing to play")
            }
            
            if self.audioPlayer!.play() {
                if !self.isPlaying {
                    NSLog("Terminate AlarmSound - not playing after calling play")
                    NSLog("Terminate AlarmSound - rate value: \(self.audioPlayer!.rate)")
                }
            } else {
                NSLog("Terminate AlarmSound - audio player failed to play")
            }
            
            
            MPVolumeView.setVolume(1.0)
           
            
        } catch let error {
            NSLog("Terminate AlarmSound - unable to play sound; error: \(error)")
        }
    }

    
    fileprivate static func restoreSystemOutputVolume() {
        
        guard UserDefaultsRepository.overrideSystemOutputVolume.value else {
            return
        }
        
        // cancel any volume change observations
       // self.volumeChangeDetector.isActive = false
        
        // restore system output volume with its value before overriding it
        if let volumeBeforeOverride = self.systemOutputVolumeBeforeOverride {
            MPVolumeView.setVolume(volumeBeforeOverride)
        }
        
        self.systemOutputVolumeBeforeOverride = nil
    }

    fileprivate static func enableAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            LogManager.shared.log(category: .general, message: "Enable audio error: \(error)")
        }
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {

    /* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. This method is NOT called if the player is stopped due to an interruption. */
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        LogManager.shared.log(category: .general, message: "AlarmRule - audioPlayerDidFinishPlaying (\(flag))", isDebug: true)
    }
    
    /* if an error occurs while decoding it will be reported to the delegate. */
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            LogManager.shared.log(category: .general, message: "AlarmRule - audioPlayerDecodeErrorDidOccur: \(error)")
        } else {
            LogManager.shared.log(category: .general, message: "AlarmRule - audioPlayerDecodeErrorDidOccur")
        }
    }
    
    /* AVAudioPlayer INTERRUPTION NOTIFICATIONS ARE DEPRECATED - Use AVAudioSession instead. */
    
    /* audioPlayerBeginInterruption: is called when the audio session has been interrupted while the player was playing. The player will have been paused. */
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        LogManager.shared.log(category: .general, message: "AlarmRule - audioPlayerBeginInterruption")
    }
    
    
    /* audioPlayerEndInterruption:withOptions: is called when the audio session interruption has ended and this player had been interrupted while playing. */
    /* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        LogManager.shared.log(category: .general, message: "AlarmRule - audioPlayerEndInterruption withOptions: \(flags)")
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
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
