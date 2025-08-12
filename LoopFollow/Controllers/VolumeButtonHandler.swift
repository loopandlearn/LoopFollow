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

    // Improved volume button detection parameters
    private let volumeButtonPressThreshold: Float = 0.02 // Minimum volume change to consider a button press
    private let volumeButtonPressTimeWindow: TimeInterval = 0.3 // Time window to detect rapid volume changes
    private let volumeButtonCooldown: TimeInterval = 0.5 // Cooldown between button presses

    private var lastVolume: Float = 0.0
    private var isMonitoring = false
    private var volumeMonitoringTimer: Timer?
    private var volumeChangeTimer: Timer?
    private var alarmStartTime: Date?
    private var hasReceivedFirstVolumeAfterAlarm: Bool = false
    private var lastVolumeButtonPressTime: Date?
    private var consecutiveVolumeChanges: Int = 0
    private var isAlarmSystemChangingVolume: Bool = false

    // Improved button press detection
    private var recentVolumeChanges: [(volume: Float, timestamp: Date)] = []
    private var lastSignificantVolumeChange: Date?
    private var volumeChangePattern: [TimeInterval] = [] // Track timing between changes

    override private init() {
        super.init()
    }

    func startMonitoring() {
        guard !isMonitoring else {
            LogManager.shared.log(category: .alarm, message: "Volume monitoring already active")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            lastVolume = AVAudioSession.sharedInstance().outputVolume
            isMonitoring = true

            LogManager.shared.log(category: .alarm, message: "Initial volume: \(lastVolume)")

            // Test volume monitoring after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let currentVol = AVAudioSession.sharedInstance().outputVolume
                LogManager.shared.log(category: .alarm, message: "Volume monitoring test - current volume: \(currentVol)")
            }

            // Listen for alarm start/stop notifications
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

            // Listen for app state changes to handle background/foreground transitions
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

            LogManager.shared.log(category: .alarm, message: "Volume button monitoring started (waiting for alarm)")
        } catch {
            LogManager.shared.log(category: .alarm, message: "Failed to start volume monitoring: \(error)")
            // Reset state on failure
            isMonitoring = false
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        stopVolumeMonitoringTimer()
        volumeChangeTimer?.invalidate()
        volumeChangeTimer = nil

        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: .alarmStarted, object: nil)
        NotificationCenter.default.removeObserver(self, name: .alarmStopped, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)

        LogManager.shared.log(category: .alarm, message: "Volume button monitoring stopped")
    }

    private func checkVolumeChange() {
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        let volumeDifference = abs(currentVolume - lastVolume)
        let now = Date()

        // Log volume changes for debugging
        if volumeDifference > 0.01 {
            LogManager.shared.log(category: .alarm, message: "Volume change: \(lastVolume) -> \(currentVolume) (diff: \(volumeDifference))")
        }

        // Only respond to significant volume changes (likely from hardware buttons)
        if volumeDifference > volumeButtonPressThreshold {
            LogManager.shared.log(category: .alarm, message: "Significant volume change detected: \(volumeDifference) (threshold: \(volumeButtonPressThreshold))")

            // Check if this volume change is likely from the alarm system
            if let startTime = alarmStartTime {
                let timeSinceAlarmStart = now.timeIntervalSince(startTime)

                // If the alarm just started and this is a volume change in the expected direction (increase),
                // it's likely from the alarm system setting the volume
                if timeSinceAlarmStart < 2.0, currentVolume > lastVolume {
                    // Additional check: if this volume change matches the expected pattern from alarm system
                    // (typically a small increase to ensure alarm is audible)
                    if volumeDifference <= 0.15, timeSinceAlarmStart < 1.5 {
                        LogManager.shared.log(category: .alarm, message: "Ignoring volume change likely from alarm system: \(lastVolume) -> \(currentVolume) (alarm started \(timeSinceAlarmStart)s ago)")
                        lastVolume = currentVolume
                        return
                    }
                }
            }

            // Record this volume change for pattern analysis
            recordVolumeChange(currentVolume: currentVolume, timestamp: now)

            // Additional check: ensure we're not just getting the initial volume reading
            if lastVolume > 0 {
                // Check if there's an active alarm
                if let startTime = alarmStartTime {
                    let timeSinceAlarmStart = now.timeIntervalSince(startTime)
                    LogManager.shared.log(category: .alarm, message: "Alarm active for \(timeSinceAlarmStart)s, activation delay: \(volumeButtonActivationDelay)s")

                    if timeSinceAlarmStart > volumeButtonActivationDelay {
                        // Check if we've pressed volume buttons recently (cooldown)
                        if let lastPress = lastVolumeButtonPressTime {
                            let timeSinceLastPress = now.timeIntervalSince(lastPress)
                            if timeSinceLastPress < volumeButtonCooldown {
                                LogManager.shared.log(category: .alarm, message: "Volume button pressed too recently (\(timeSinceLastPress)s ago), ignoring")
                                return
                            }
                        }

                        // Improved button press detection
                        if isLikelyVolumeButtonPress(volumeDifference: volumeDifference, timestamp: now) {
                            LogManager.shared.log(category: .alarm, message: "Volume button press detected: \(volumeDifference), handling volume button press")
                            handleVolumeButtonPress()
                        } else {
                            LogManager.shared.log(category: .alarm, message: "Volume change detected but not recognized as button press: \(volumeDifference)")
                        }
                    } else {
                        LogManager.shared.log(category: .alarm, message: "Volume change detected but alarm hasn't been playing long enough: \(timeSinceAlarmStart)s (need \(volumeButtonActivationDelay)s)")
                    }
                } else {
                    LogManager.shared.log(category: .alarm, message: "Volume change detected but no alarm start time recorded")
                }
            } else {
                LogManager.shared.log(category: .alarm, message: "Volume change detected but lastVolume is 0")
            }
        }

        lastVolume = currentVolume
    }

    // MARK: - Improved Button Press Detection

    private func recordVolumeChange(currentVolume: Float, timestamp: Date) {
        // Add this volume change to our recent history
        recentVolumeChanges.append((volume: currentVolume, timestamp: timestamp))

        // Keep only recent changes (within the time window)
        let cutoffTime = timestamp.timeIntervalSinceReferenceDate - volumeButtonPressTimeWindow
        recentVolumeChanges = recentVolumeChanges.filter { $0.timestamp.timeIntervalSinceReferenceDate > cutoffTime }

        // Update pattern tracking
        if let lastChange = lastSignificantVolumeChange {
            let timeSinceLastChange = timestamp.timeIntervalSince(lastChange)
            volumeChangePattern.append(timeSinceLastChange)

            // Keep only recent patterns
            if volumeChangePattern.count > 5 {
                volumeChangePattern.removeFirst()
            }
        }

        lastSignificantVolumeChange = timestamp
    }

    private func isLikelyVolumeButtonPress(volumeDifference: Float, timestamp: Date) -> Bool {
        // Criteria for identifying a volume button press:

        // 1. Volume change should be significant but not too large (typical button press range)
        // Make this more strict to avoid system volume changes
        let isReasonableChange = volumeDifference >= 0.03 && volumeDifference <= 0.12

        // 2. Should be a discrete change (not part of a continuous adjustment)
        let isDiscreteChange = recentVolumeChanges.count <= 2

        // 3. Timing should be consistent with button press patterns
        let hasConsistentTiming = volumeChangePattern.isEmpty ||
            volumeChangePattern.last! >= 0.15 // At least 150ms between changes (increased from 100ms)

        // 4. Should not be part of a rapid sequence (which might indicate slider usage)
        let isNotRapidSequence = recentVolumeChanges.count < 3 ||
            (recentVolumeChanges.count >= 3 &&
                recentVolumeChanges.suffix(3).map { $0.timestamp.timeIntervalSinceReferenceDate }.enumerated().dropFirst().allSatisfy { index, timestamp in
                    let previousTimestamp = recentVolumeChanges.suffix(3).map { $0.timestamp.timeIntervalSinceReferenceDate }[index - 1]
                    return timestamp - previousTimestamp > 0.08 // At least 80ms between rapid changes (increased from 50ms)
                })

        let isButtonPress = isReasonableChange && isDiscreteChange && hasConsistentTiming && isNotRapidSequence

        LogManager.shared.log(category: .alarm, message: "Button press analysis: change=\(volumeDifference), discrete=\(isDiscreteChange), timing=\(hasConsistentTiming), rapid=\(!isNotRapidSequence), result=\(isButtonPress)")

        return isButtonPress
    }

    private func handleVolumeButtonPress() {
        LogManager.shared.log(category: .alarm, message: "=== handleVolumeButtonPress called ===")
        LogManager.shared.log(category: .alarm, message: "Current time: \(Date())")
        LogManager.shared.log(category: .alarm, message: "Alarm start time: \(alarmStartTime?.description ?? "nil")")
        LogManager.shared.log(category: .alarm, message: "AlarmSound.isPlaying: \(AlarmSound.isPlaying)")

        // Check if volume button silencing is enabled
        guard Storage.shared.alarmConfiguration.value.enableVolumeButtonSilence else {
            LogManager.shared.log(category: .alarm, message: "Volume button silencing is disabled")
            return
        }

        // Check if there's an active alarm
        guard AlarmSound.isPlaying else {
            LogManager.shared.log(category: .alarm, message: "No alarm is currently playing")
            return
        }

        // Prevent multiple rapid triggers
        guard volumeChangeTimer == nil else {
            LogManager.shared.log(category: .alarm, message: "Volume change timer already active, ignoring")
            return
        }

        LogManager.shared.log(category: .alarm, message: "Immediately silencing alarm")

        // Silence the alarm immediately without delay
        silenceActiveAlarm()
    }

    private func silenceActiveAlarm() {
        LogManager.shared.log(category: .alarm, message: "Volume button pressed - silencing active alarm")

        // Record the time of this volume button press
        lastVolumeButtonPressTime = Date()

        // Check if alarm is still playing before stopping
        let wasPlaying = AlarmSound.isPlaying
        LogManager.shared.log(category: .alarm, message: "Alarm was playing: \(wasPlaying)")

        // Stop the alarm sound
        AlarmSound.stop()

        // Check if alarm stopped
        let isStillPlaying = AlarmSound.isPlaying
        LogManager.shared.log(category: .alarm, message: "Alarm is still playing after stop: \(isStillPlaying)")

        // Perform snooze on the current alarm
        AlarmManager.shared.performSnooze()

        // Log snooze details
        if let currentAlarmID = Observable.shared.currentAlarm.value {
            let alarms = Storage.shared.alarms.value
            if let alarm = alarms.first(where: { $0.id == currentAlarmID }) {
                LogManager.shared.log(category: .alarm, message: "Snoozed alarm: \(alarm.name), snooze duration: \(alarm.snoozeDuration) units")
            }
        }

        LogManager.shared.log(category: .alarm, message: "Alarm silenced and snoozed via volume button")

        // Check if snooze was successful
        DispatchQueue.main.asyncAfter(deadline: .now() + volumeButtonActivationDelay) {
            if let currentAlarm = Observable.shared.currentAlarm.value {
                LogManager.shared.log(category: .alarm, message: "Current alarm after snooze: \(currentAlarm)")
            } else {
                LogManager.shared.log(category: .alarm, message: "No current alarm after snooze - snooze successful")
            }
        }

        // Provide haptic feedback to confirm the action
        if #available(iOS 10.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }

    // MARK: - Notification Handlers

    @objc private func alarmStarted() {
        alarmStartTime = Date()
        hasReceivedFirstVolumeAfterAlarm = false
        consecutiveVolumeChanges = 0

        // Reset improved button press detection
        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()

        LogManager.shared.log(category: .alarm, message: "Alarm started - volume button silencing enabled after \(volumeButtonActivationDelay) seconds")

        // Start volume monitoring after the activation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + volumeButtonActivationDelay) {
            if let startTime = self.alarmStartTime {
                let timeSince = Date().timeIntervalSince(startTime)
                LogManager.shared.log(category: .alarm, message: "Alarm has been playing for \(timeSince)s - volume button silencing now active")

                // Start the volume monitoring timer now that the alarm is active
                self.startVolumeMonitoringTimer()

                // Mark that we're ready to receive volume button presses
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

        // Stop the volume monitoring timer since no alarm is active
        stopVolumeMonitoringTimer()

        // Reset improved button press detection
        recentVolumeChanges.removeAll()
        lastSignificantVolumeChange = nil
        volumeChangePattern.removeAll()

        LogManager.shared.log(category: .alarm, message: "Alarm stopped - volume button silencing disabled")
    }

    // MARK: - App State Change Handlers

    @objc private func appDidEnterBackground() {
        let backgroundType = Storage.shared.backgroundRefreshType.value
        let volumeButtonEnabled = Storage.shared.alarmConfiguration.value.enableVolumeButtonSilence

        if backgroundType.isBluetooth || backgroundType == .silentTune, volumeButtonEnabled {
            let method = backgroundType == .silentTune ? "Silent Tune" : "Bluetooth"
            LogManager.shared.log(category: .alarm, message: "App entered background with \(method) refresh and volume button snoozing enabled - maintaining volume monitoring for alarms")
            // Keep volume monitoring active for Bluetooth/Silent Tune background refresh when volume button snoozing is enabled
            // This allows volume button snoozing to work in the background
        } else {
            LogManager.shared.log(category: .alarm, message: "App entered background - volume monitoring may be limited or disabled")
        }
    }

    @objc private func appWillEnterForeground() {
        LogManager.shared.log(category: .alarm, message: "App will enter foreground - ensuring volume monitoring is active")
        // Ensure volume monitoring is active when coming to foreground
        if isMonitoring, volumeMonitoringTimer == nil {
            startVolumeMonitoringTimer()
        }
    }

    // MARK: - Timer Management

    private func startVolumeMonitoringTimer() {
        // Only start if not already running
        guard volumeMonitoringTimer == nil else {
            LogManager.shared.log(category: .alarm, message: "Volume monitoring timer already running")
            return
        }

        // Use a more background-compatible timer approach
        volumeMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.checkVolumeChange()
        }

        // Ensure the timer works in background by adding it to the main run loop
        // Use .common mode for better background compatibility
        RunLoop.main.add(volumeMonitoringTimer!, forMode: .common)

        // Also add to default mode as backup
        RunLoop.main.add(volumeMonitoringTimer!, forMode: .default)

        LogManager.shared.log(category: .alarm, message: "Volume monitoring timer started")
    }

    private func stopVolumeMonitoringTimer() {
        volumeMonitoringTimer?.invalidate()
        volumeMonitoringTimer = nil
        LogManager.shared.log(category: .alarm, message: "Volume monitoring timer stopped")
    }

    // MARK: - Testing

    func testSnoozeFunctionality() {
        LogManager.shared.log(category: .alarm, message: "Testing snooze functionality manually")
        silenceActiveAlarm()
    }
}
