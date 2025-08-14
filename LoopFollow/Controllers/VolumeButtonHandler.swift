// LoopFollow
// VolumeButtonHandler.swift
// Created by codebymini.

import AVFoundation
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
    private var volumeChangeTimer: Timer?
    private var alarmStartTime: Date?
    private var hasReceivedFirstVolumeAfterAlarm: Bool = false
    private var lastVolumeButtonPressTime: Date?
    private var consecutiveVolumeChanges: Int = 0
    private var isAlarmSystemChangingVolume: Bool = false

    // Button press detection
    private var recentVolumeChanges: [(volume: Float, timestamp: Date)] = []
    private var lastSignificantVolumeChange: Date?
    private var volumeChangePattern: [TimeInterval] = []

    override private init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(alarmStarted),
            name: .alarmStarted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(alarmStopped),
            name: .alarmStopped,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Try to get volume without activating audio session first
        let audioSession = AVAudioSession.sharedInstance()
        let currentVolume = audioSession.outputVolume

        // If we can get volume without activation, use that approach
        if currentVolume > 0 {
            lastVolume = currentVolume
            isMonitoring = true
            startVolumeMonitoringTimer()
            return
        }

        // Only activate audio session if we can't get volume passively
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            lastVolume = audioSession.outputVolume
            isMonitoring = true
            startVolumeMonitoringTimer()
        } catch {
            LogManager.shared.log(category: .alarm, message: "Failed to start volume monitoring: \(error)")
            isMonitoring = false
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        stopVolumeMonitoringTimer()
        volumeChangeTimer?.invalidate()
        volumeChangeTimer = nil

        // Only deactivate audio session if we activated it
        if AVAudioSession.sharedInstance().isOtherAudioPlaying == false {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                LogManager.shared.log(category: .alarm, message: "Failed to deactivate audio session: \(error)")
            }
        }
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
                        handleVolumeButtonPress()
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

    private func handleVolumeButtonPress() {
        guard Storage.shared.alarmConfiguration.value.enableVolumeButtonSnooze else { return }
        guard AlarmSound.isPlaying else { return }
        guard volumeChangeTimer == nil else { return }

        silenceActiveAlarm()
    }

    private func silenceActiveAlarm() {
        lastVolumeButtonPressTime = Date()
        AlarmSound.stop()
        AlarmManager.shared.performSnooze()

        if #available(iOS 10.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }

    @objc private func alarmStarted() {
        alarmStartTime = Date()
        hasReceivedFirstVolumeAfterAlarm = false
        consecutiveVolumeChanges = 0

        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()

        startMonitoring()

        DispatchQueue.main.asyncAfter(deadline: .now() + volumeButtonActivationDelay) {
            if let startTime = self.alarmStartTime {
                self.hasReceivedFirstVolumeAfterAlarm = true
            }
        }
    }

    @objc private func alarmStopped() {
        alarmStartTime = nil
        hasReceivedFirstVolumeAfterAlarm = false
        consecutiveVolumeChanges = 0
        volumeChangeTimer?.invalidate()
        volumeChangeTimer = nil

        stopMonitoring()

        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()
    }

    @objc private func appDidEnterBackground() {
        let backgroundType = Storage.shared.backgroundRefreshType.value
        let volumeButtonEnabled = Storage.shared.alarmConfiguration.value.enableVolumeButtonSnooze

        if backgroundType.isBluetooth || backgroundType == .silentTune, volumeButtonEnabled {
            // Keep volume monitoring active for background refresh
        }
    }

    @objc private func appWillEnterForeground() {
        if let startTime = alarmStartTime, isMonitoring, volumeMonitoringTimer == nil {
            startVolumeMonitoringTimer()
        }
    }

    private func startVolumeMonitoringTimer() {
        guard volumeMonitoringTimer == nil else { return }

        volumeMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.checkVolumeChange()
        }

        RunLoop.main.add(volumeMonitoringTimer!, forMode: .common)
        RunLoop.main.add(volumeMonitoringTimer!, forMode: .default)
    }

    private func stopVolumeMonitoringTimer() {
        volumeMonitoringTimer?.invalidate()
        volumeMonitoringTimer = nil
    }

    func testSnoozeFunctionality() {
        silenceActiveAlarm()
    }
}
