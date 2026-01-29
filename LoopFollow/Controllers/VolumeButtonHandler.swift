// LoopFollow
// VolumeButtonHandler.swift

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

class VolumeButtonHandler: NSObject {
    static let shared = VolumeButtonHandler()

    /// Volume button snoozer activation delay in seconds
    private let volumeButtonActivationDelay: TimeInterval = 0.9

    // Volume button detection parameters
    private let volumeButtonPressThreshold: Float = 0.02
    private let volumeButtonPressTimeWindow: TimeInterval = 0.3
    private let volumeButtonCooldown: TimeInterval = 0.5

    /// KVO observer for system volume
    private var volumeObserver: NSKeyValueObservation?

    private var lastVolume: Float = 0.0
    private var isMonitoring = false
    private var alarmStartTime: Date?
    private var lastVolumeButtonPressTime: Date?

    // Button press detection
    private var recentVolumeChanges: [(volume: Float, timestamp: Date)] = []
    private var lastSignificantVolumeChange: Date?
    private var volumeChangePattern: [TimeInterval] = []

    /// Remote command center for handling bluetooth/CarPlay buttons
    private var remoteCommandsEnabled = false

    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()

        Observable.shared.alarmSoundPlaying.$value
            .removeDuplicates()
            .sink { [weak self] alarmSoundPlaying in
                guard let self = self else { return }
                if alarmSoundPlaying {
                    self.alarmStarted()
                } else {
                    self.alarmStopped()
                }
            }
            .store(in: &cancellables)
    }

    private func recordVolumeChange(currentVolume: Float, timestamp: Date) {
        recentVolumeChanges.append((volume: currentVolume, timestamp: timestamp))

        let cutoffTime = timestamp.timeIntervalSinceReferenceDate - volumeButtonPressTimeWindow
        recentVolumeChanges = recentVolumeChanges.filter { $0.timestamp.timeIntervalSinceReferenceDate > cutoffTime }

        if let lastChange = lastSignificantVolumeChange {
            let timeSinceLastChange = timestamp.timeIntervalSince(lastChange)
            volumeChangePattern.append(timeSinceLastChange)

            if volumeChangePattern.count > 5 {
                volumeChangePattern.removeFirst()
            }
        }
        lastSignificantVolumeChange = timestamp
    }

    private func isLikelyVolumeButtonPress(volumeDifference: Float, timestamp: Date) -> Bool {
        let isReasonableChange = volumeDifference >= 0.03 && volumeDifference <= 0.12
        let isDiscreteChange = recentVolumeChanges.count <= 2
        let hasConsistentTiming = volumeChangePattern.isEmpty || volumeChangePattern.last! >= 0.15
        let isNotRapidSequence = recentVolumeChanges.count < 3 ||
            (recentVolumeChanges.count >= 3 &&
                recentVolumeChanges.suffix(3).map { $0.timestamp.timeIntervalSinceReferenceDate }.enumerated().dropFirst().allSatisfy { index, timestamp in
                    let previousTimestamp = recentVolumeChanges.suffix(3).map { $0.timestamp.timeIntervalSinceReferenceDate }[index - 1]
                    return timestamp - previousTimestamp > 0.08
                })

        return isReasonableChange && isDiscreteChange && hasConsistentTiming && isNotRapidSequence
    }

    private func snoozeActiveAlarm() {
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Snoozing alarm")

        lastVolumeButtonPressTime = Date()
        AlarmManager.shared.performSnooze()

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func alarmStarted() {
        guard Storage.shared.alarmConfiguration.value.enableVolumeButtonSnooze else { return }
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Alarm start detected, setting up volume observer.")

        alarmStartTime = Date()
        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()

        startMonitoring()
    }

    private func alarmStopped() {
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Alarm stop detected")

        alarmStartTime = nil
        stopMonitoring()

        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()
    }

    private func setupRemoteCommandCenter() {
        guard !remoteCommandsEnabled else { return }

        let commandCenter = MPRemoteCommandCenter.shared()

        // Log current audio route to help with debugging
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Audio route: \(currentRoute.outputs.map { $0.portName }.joined(separator: ", "))")

        // Enable pause command - handles play/pause button on bluetooth devices and CarPlay
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }

            LogManager.shared.log(category: .volumeButtonSnooze, message: "Pause command received from remote")

            // Check if alarm is currently active and activation delay has passed
            if let alarmStartTime = self.alarmStartTime {
                let timeSinceAlarmStart = Date().timeIntervalSince(alarmStartTime)

                if timeSinceAlarmStart > self.volumeButtonActivationDelay {
                    // Check cooldown
                    if let lastPress = self.lastVolumeButtonPressTime {
                        let timeSinceLastPress = Date().timeIntervalSince(lastPress)
                        if timeSinceLastPress < self.volumeButtonCooldown {
                            return .success
                        }
                    }

                    LogManager.shared.log(category: .volumeButtonSnooze, message: "Remote command pause received - snoozing alarm")
                    self.snoozeActiveAlarm()
                    return .success
                }
            }

            return .commandFailed
        }

        // Enable play command as well for symmetry
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }

            LogManager.shared.log(category: .volumeButtonSnooze, message: "Play command received from remote")

            if let alarmStartTime = self.alarmStartTime {
                let timeSinceAlarmStart = Date().timeIntervalSince(alarmStartTime)

                if timeSinceAlarmStart > self.volumeButtonActivationDelay {
                    if let lastPress = self.lastVolumeButtonPressTime {
                        let timeSinceLastPress = Date().timeIntervalSince(lastPress)
                        if timeSinceLastPress < self.volumeButtonCooldown {
                            return .success
                        }
                    }

                    LogManager.shared.log(category: .volumeButtonSnooze, message: "Remote command play received - snoozing alarm")
                    self.snoozeActiveAlarm()
                    return .success
                }
            }

            return .commandFailed
        }

        // Enable toggle play/pause command - common on many bluetooth devices
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }

            LogManager.shared.log(category: .volumeButtonSnooze, message: "Toggle play/pause command received from remote")

            if let alarmStartTime = self.alarmStartTime {
                let timeSinceAlarmStart = Date().timeIntervalSince(alarmStartTime)

                if timeSinceAlarmStart > self.volumeButtonActivationDelay {
                    if let lastPress = self.lastVolumeButtonPressTime {
                        let timeSinceLastPress = Date().timeIntervalSince(lastPress)
                        if timeSinceLastPress < self.volumeButtonCooldown {
                            return .success
                        }
                    }

                    LogManager.shared.log(category: .volumeButtonSnooze, message: "Remote command toggle play/pause received - snoozing alarm")
                    self.snoozeActiveAlarm()
                    return .success
                }
            }

            return .commandFailed
        }

        remoteCommandsEnabled = true
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Remote command center configured for bluetooth/CarPlay button handling")
    }

    private func disableRemoteCommandCenter() {
        guard remoteCommandsEnabled else { return }

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.playCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false

        // Remove all targets
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)

        remoteCommandsEnabled = false
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Remote command center disabled")
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Setup remote command center for bluetooth/CarPlay button handling
        setupRemoteCommandCenter()

        volumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] session, _ in
            guard let self = self, let alarmStartTime = self.alarmStartTime else { return }

            let currentVolume = session.outputVolume
            let now = Date()

            // On the first observation, capture the initial volume when the audio session
            // becomes active. This solves the race condition. We then return to avoid
            // treating this initial setup as a user-initiated button press.
            if self.lastVolume == 0.0, currentVolume > 0.0 {
                LogManager.shared.log(category: .volumeButtonSnooze, message: "Observer received initial valid volume: \(currentVolume)")
                self.lastVolume = currentVolume
                return
            }

            guard self.lastVolume > 0.0 else { return }

            let volumeDifference = abs(currentVolume - self.lastVolume)

            if volumeDifference > self.volumeButtonPressThreshold {
                let timeSinceAlarmStart = now.timeIntervalSince(alarmStartTime)

                // Ignore volume changes from the alarm system's own ramp-up.
                if timeSinceAlarmStart < 2.0, currentVolume > self.lastVolume {
                    if volumeDifference <= 0.15, timeSinceAlarmStart < 1.5 {
                        self.lastVolume = currentVolume
                        return
                    }
                }

                self.recordVolumeChange(currentVolume: currentVolume, timestamp: now)

                if timeSinceAlarmStart > self.volumeButtonActivationDelay {
                    if let lastPress = self.lastVolumeButtonPressTime {
                        let timeSinceLastPress = now.timeIntervalSince(lastPress)
                        if timeSinceLastPress < self.volumeButtonCooldown {
                            self.lastVolume = currentVolume
                            return
                        }
                    }

                    if self.isLikelyVolumeButtonPress(volumeDifference: volumeDifference, timestamp: now) {
                        self.snoozeActiveAlarm()
                    }
                }
            }
            self.lastVolume = currentVolume
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        LogManager.shared.log(category: .volumeButtonSnooze, message: "Invalidating volume observer.")

        // Invalidate the observer to stop receiving notifications and prevent memory leaks.
        volumeObserver?.invalidate()
        volumeObserver = nil

        // Disable remote command center
        disableRemoteCommandCenter()

        isMonitoring = false
        lastVolume = 0.0 // Reset for the next alarm.
    }
}
