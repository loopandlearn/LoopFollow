// LoopFollow
// VolumeButtonHandler.swift

import AVFoundation
import Combine
import Foundation
import UIKit

class VolumeButtonHandler: NSObject {
    static let shared = VolumeButtonHandler()

    // Volume button snoozer activation delay in seconds
    private let volumeButtonActivationDelay: TimeInterval = 0.9

    // Volume button detection parameters
    private let volumeButtonPressThreshold: Float = 0.02
    private let volumeButtonPressTimeWindow: TimeInterval = 0.3
    private let volumeButtonCooldown: TimeInterval = 0.5

    private var lastVolume: Float = 0.0
    private var isMonitoring = false
    private var volumeMonitoringTimer: Timer?
    private var alarmStartTime: Date?
    private var lastVolumeButtonPressTime: Date?

    // Button press detection
    private var recentVolumeChanges: [(volume: Float, timestamp: Date)] = []
    private var lastSignificantVolumeChange: Date?
    private var volumeChangePattern: [TimeInterval] = []

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

    private func checkVolumeChange() {
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        let volumeDifference = abs(currentVolume - lastVolume)
        let now = Date()

        if volumeDifference > volumeButtonPressThreshold {
            if let startTime = alarmStartTime {
                let timeSinceAlarmStart = now.timeIntervalSince(startTime)

                // Ignore volume changes from alarm system
                if timeSinceAlarmStart < 2.0, currentVolume > lastVolume {
                    if volumeDifference <= 0.15, timeSinceAlarmStart < 1.5 {
                        lastVolume = currentVolume
                        return
                    }
                }
            }

            recordVolumeChange(currentVolume: currentVolume, timestamp: now)

            if lastVolume > 0, let startTime = alarmStartTime {
                let timeSinceAlarmStart = now.timeIntervalSince(startTime)

                if timeSinceAlarmStart > volumeButtonActivationDelay {
                    if let lastPress = lastVolumeButtonPressTime {
                        let timeSinceLastPress = now.timeIntervalSince(lastPress)
                        if timeSinceLastPress < volumeButtonCooldown { return }
                    }

                    if isLikelyVolumeButtonPress(volumeDifference: volumeDifference, timestamp: now) {
                        snoozeActiveAlarm()
                    }
                }
            }
        }

        lastVolume = currentVolume
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

        LogManager.shared.log(category: .volumeButtonSnooze, message: "Alarm start detected")
        alarmStartTime = Date()

        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()

        startMonitoring()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        let audioSession = AVAudioSession.sharedInstance()
        let currentVolume = audioSession.outputVolume

        if currentVolume > 0 {
            lastVolume = currentVolume
            isMonitoring = true
            startVolumeMonitoringTimer()
            return
        }

        LogManager.shared.log(category: .volumeButtonSnooze, message: "Did not get a valid volume, not monitoring")
    }

    private func startVolumeMonitoringTimer() {
        guard volumeMonitoringTimer == nil else { return }

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkVolumeChange()
        }

        volumeMonitoringTimer = timer

        RunLoop.main.add(timer, forMode: .common)
    }

    private func alarmStopped() {
        LogManager.shared.log(category: .volumeButtonSnooze, message: "Alarm stop detected")

        alarmStartTime = nil

        stopMonitoring()

        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

        volumeMonitoringTimer?.invalidate()
        volumeMonitoringTimer = nil
    }
}
