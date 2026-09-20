// LoopFollow
// BackgroundTaskAudio.swift

import AVFoundation
import UIKit

/// Keeps the app running in the background by looping a silent audio file.
///
/// The audio session is the only background-execution claim Silent Tune has, so
/// losing it means the process is suspended within seconds and no app code —
/// including any retry timer — runs again until iOS resumes the app. Every
/// reactivation attempt therefore runs inside a `UIApplication` background-task
/// assertion, which grants runtime independently of the audio claim, and the
/// attempts are bounded to stay inside that assertion's budget.
class BackgroundTask {
    // MARK: - Vars

    var player = AVAudioPlayer()

    /// True while the silent loop actually holds the background-audio claim.
    var isPlaying: Bool { player.isPlaying }

    /// Attempts spread over `retryInterval`, sized to fit a background-task
    /// assertion (~30s) and a `BGAppRefreshTask` window with room to spare.
    private let maxAttempts = 10
    private let retryInterval: TimeInterval = 2.0

    /// Delay before the first attempt after an interruption ends, letting the
    /// interrupting app (e.g. Clock alarm) fully release the audio session.
    /// Without it `setActive(true)` races with the alarm and fails with
    /// `AVAudioSession.ErrorCode.cannotInterruptOthers` (560557684).
    private let postInterruptionDelay: TimeInterval = 0.5

    /// Window after an interruption begins in which a matching `.ended` supersedes
    /// the recovery. Longer than `postInterruptionDelay` so a blip's own restart
    /// lands first; short enough that a real claim loss is addressed promptly.
    private let interruptionSettleDelay: TimeInterval = 1.0

    private var recoveryWorkItem: DispatchWorkItem?
    private var assertionID: UIBackgroundTaskIdentifier = .invalid

    /// Callers waiting on the outcome. A caller holding a `BGAppRefreshTask` open
    /// must always hear back so it can complete the task, so a sequence that
    /// supersedes another inherits its waiters.
    private var pendingCompletions: [(Bool) -> Void] = []

    /// Per-sequence diagnostics: how long recovery has been running, how many
    /// attempts it took, and the last session error. A first-attempt success stays
    /// quiet; anything slower reports what it cost.
    private var sequenceStart: Date?
    private var attemptsMade = 0
    private var lastFailureCode: Int?

    /// Set when a sequence runs out of attempts, so the eventual recovery is reported
    /// at full level however it arrives.
    private var lastSequenceGaveUp = false

    /// True while the active sequence was started by an interruption beginning.
    /// Exhausting the attempts there is expected for any interrupter that outlasts
    /// the assertion (a phone call), and iOS still commonly heals it by delivering
    /// `.ended`, so that case must not be announced as a failed keep-alive.
    private var startedByInterruption = false

    // MARK: - Methods

    func startBackgroundTask() {
        attachObservers()
        onMain { self.recover(after: 0, reason: "start") }
    }

    /// Idempotent. A process launched into the background by `BGAppRefreshTask` never
    /// sees a backgrounding transition, so the keep-alive attaches these wherever it
    /// starts.
    private func attachObservers() {
        removeObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(interruptedAudio), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        // A route disappearing pauses the player without any interruption notification,
        // and a media services reset invalidates the session and player outright —
        // neither is observable through `interruptionNotification`.
        NotificationCenter.default.addObserver(self, selector: #selector(audioRouteChanged), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaServicesWereReset), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    func stopBackgroundTask() {
        removeObservers()
        onMain {
            self.cancelRecovery()
            self.player.stop()
            // Reached only from the foreground transition: with the app open, the
            // next backgrounding is a clean start.
            self.lastSequenceGaveUp = false
            LogManager.shared.log(category: .general, message: "Silent audio stopped", isDebug: true)
        }
    }

    /// Reactivates the silent loop, retrying until it plays or the attempt budget
    /// is spent, and reports the outcome. Runtime is held by a background-task
    /// assertion for the whole sequence, so the retries survive the loss of the
    /// audio claim that made them necessary.
    /// - Parameter completion: Called on the main queue with the final state.
    func restartAudio(reason: String, completion: ((Bool) -> Void)? = nil) {
        attachObservers()
        onMain {
            self.player.stop()
            self.recover(after: 0, reason: reason, completion: completion)
        }
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    // MARK: - Route and media services handling

    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        let previous = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        let route = "reason=\(describe(reason)) from=\(portTypes(previous)) to=\(portTypes(AVAudioSession.sharedInstance().currentRoute))"

        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable:
            LogManager.shared.log(category: .general, message: "[LA] Audio route changed, restarting silent audio: \(route)")
            // CarPlay and Bluetooth transitions emit a burst of route changes; each
            // supersedes the last, so the ladder runs once against the settled route.
            onMain { self.recover(after: self.interruptionSettleDelay, reason: "route change") }

        case .categoryChange:
            // `playAudio` sets the category itself, and an alarm takes over the
            // session the same way. Both make this reason unsafe to act on.
            LogManager.shared.log(category: .general, message: "[LA] Audio route changed, ignoring: \(route)", isDebug: true)

        default:
            // Recorded for diagnosis without acting.
            LogManager.shared.log(category: .general, message: "[LA] Audio route changed, no action: \(route)")
        }
    }

    @objc private func mediaServicesWereReset(_: Notification) {
        LogManager.shared.log(category: .general, message: "[LA] Media services were reset — session and player are invalid, rebuilding")
        // `playAudio` reconfigures the category, reactivates, and creates a fresh
        // player, which is the recovery Apple prescribes for a reset.
        onMain { self.recover(after: self.interruptionSettleDelay, reason: "media services reset") }
    }

    /// Port types only — `portName` carries the user's accessory name, which must not
    /// reach a shared log.
    private func portTypes(_ route: AVAudioSessionRouteDescription?) -> String {
        guard let route, !route.outputs.isEmpty else { return "none" }
        return route.outputs.map { $0.portType.rawValue }.joined(separator: "+")
    }

    private func describe(_ reason: AVAudioSession.RouteChangeReason) -> String {
        switch reason {
        case .newDeviceAvailable: "newDeviceAvailable"
        case .oldDeviceUnavailable: "oldDeviceUnavailable"
        case .categoryChange: "categoryChange"
        case .override: "override"
        case .wakeFromSleep: "wakeFromSleep"
        case .noSuitableRouteForCategory: "noSuitableRouteForCategory"
        case .routeConfigurationChange: "routeConfigurationChange"
        case .unknown: "unknown"
        @unknown default: "other"
        }
    }

    // MARK: - Interruption handling

    @objc private func interruptedAudio(_ notification: Notification) {
        guard notification.name == AVAudioSession.interruptionNotification,
              let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            let reason = (userInfo[AVAudioSessionInterruptionReasonKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionReason(rawValue: $0) }
            LogManager.shared.log(
                category: .general,
                message: "[LA] Silent audio session interrupted (began), reason=\(describe(reason)), otherAudioPlaying=\(AVAudioSession.sharedInstance().isOtherAudioPlaying)"
            )
            // iOS delivers `.ended` only if the app is still running, and the lost
            // audio claim means suspension is imminent, so recovery cannot wait for
            // it. The delay is a supersede window: a brief interrupter's `.ended`
            // arrives well inside it and cancels this work, so momentary blips stay
            // quiet. Work that does run is therefore a reliable signal that the
            // claim is really gone, whatever `player.isPlaying` reports.
            onMain { self.recover(after: self.interruptionSettleDelay, reason: "interruption began", startedByInterruption: true) }

        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if !options.contains(.shouldResume) {
                    LogManager.shared.log(category: .general, message: "[LA] Silent audio interruption ended — shouldResume not set, attempting restart anyway")
                }
            }
            LogManager.shared.log(category: .general, message: "[LA] Silent audio interruption ended — scheduling restart in \(postInterruptionDelay)s")
            onMain { self.recover(after: self.postInterruptionDelay, reason: "interruption ended") }

        @unknown default:
            break
        }
    }

    private func describe(_ reason: AVAudioSession.InterruptionReason?) -> String {
        switch reason {
        case .default: "default"
        case .builtInMicMuted: "builtInMicMuted"
        case .none: "unknown"
        @unknown default: "other"
        }
    }

    // MARK: - Recovery

    /// Runs one bounded recovery sequence, superseding any sequence already in flight.
    private func recover(after delay: TimeInterval, reason: String, startedByInterruption: Bool = false, completion: ((Bool) -> Void)? = nil) {
        // Waiters from the in-flight sequence inherit this sequence's outcome.
        recoveryWorkItem?.cancel()
        recoveryWorkItem = nil
        if let completion {
            pendingCompletions.append(completion)
        }
        self.startedByInterruption = startedByInterruption
        if sequenceStart == nil {
            sequenceStart = Date()
            attemptsMade = 0
            lastFailureCode = nil
        }

        // `player.isPlaying` reports true for a while after the session is taken, so
        // recovery runs unconditionally. Reattempting against a playing player is
        // harmless: `playAudio` activates the session before touching `player`, leaving
        // a working one untouched when an attempt fails.
        //
        // The assertion is taken before the delay so the first attempt is covered too.
        beginAssertion()

        guard delay > 0 else {
            attempt(1, of: reason)
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.recoveryWorkItem = nil
            self.attempt(1, of: reason)
        }
        recoveryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func attempt(_ number: Int, of reason: String) {
        attemptsMade = number
        if startedByInterruption, number == 1 {
            // Reached only when the settle window elapsed without an `.ended`, so the
            // interrupter holds the session and the app may be suspended before the
            // ladder finishes.
            BackgroundRefreshManager.shared.scheduleImmediateRefresh()
        }
        if playAudio(attempt: number, reason: reason) {
            finishRecovery(success: true)
            return
        }

        guard number < maxAttempts else {
            LogManager.shared.log(
                category: .general,
                message: "Silent audio recovery gave up after \(number) attempts over \(elapsedDescription()) (\(reason)), last error: \(Self.describeSessionError(lastFailureCode ?? 0))"
            )
            lastSequenceGaveUp = true
            if !startedByInterruption {
                NotificationCenter.default.post(name: .backgroundAudioFailed, object: nil)
            }
            // The attempts are spent and there is no audio claim left, so a background
            // refresh is the only remaining route back to running code.
            BackgroundRefreshManager.shared.scheduleImmediateRefresh()
            finishRecovery(success: false)
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.recoveryWorkItem = nil
            self.attempt(number + 1, of: reason)
        }
        recoveryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + retryInterval, execute: work)
    }

    /// - Returns: True when the silent loop is confirmed playing.
    private func playAudio(attempt: Int, reason: String) -> Bool {
        do {
            guard let path = Bundle.main.path(forResource: "blank", ofType: "wav") else {
                LogManager.shared.log(category: .general, message: "playAudio failed: blank.wav missing from bundle")
                return false
            }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            // Play audio forever by setting num of loops to -1
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            guard player.isPlaying else {
                LogManager.shared.log(category: .general, message: "playAudio: play() did not start the player (attempt \(attempt)/\(maxAttempts), \(reason))")
                return false
            }
            if attempt > 1 || lastFailureCode != nil || lastSequenceGaveUp {
                // A recovery following a logged failure reports itself, so the log
                // always says whether the failure resolved. `lastFailureCode` survives
                // a supersede, so the elapsed figure spans the whole window.
                LogManager.shared.log(category: .general, message: "Silent audio playing again after \(attempt) attempt(s) over \(elapsedDescription()) (\(reason))")
            } else {
                LogManager.shared.log(category: .general, message: "Silent audio playing (\(reason))", isDebug: true)
            }
            lastSequenceGaveUp = false
            return true
        } catch {
            let code = (error as NSError).code
            // Every attempt against the same holder reports the same code; log the
            // first and any change, so a 10-attempt ladder can't bury the log.
            let isNewFailure = code != lastFailureCode
            lastFailureCode = code
            LogManager.shared.log(
                category: .general,
                message: "playAudio failed (attempt \(attempt)/\(maxAttempts), \(reason)), code \(code) \(Self.describeSessionError(code)): \(error.localizedDescription)",
                isDebug: !isNewFailure
            )
            return false
        }
    }

    private func elapsedDescription() -> String {
        guard let start = sequenceStart else { return "unknown" }
        return String(format: "%.1fs", Date().timeIntervalSince(start))
    }

    private func finishRecovery(success: Bool) {
        recoveryWorkItem = nil
        let completions = pendingCompletions
        pendingCompletions = []
        startedByInterruption = false
        sequenceStart = nil
        attemptsMade = 0
        lastFailureCode = nil
        endAssertion()
        for completion in completions {
            completion(success)
        }
    }

    private func cancelRecovery() {
        recoveryWorkItem?.cancel()
        finishRecovery(success: player.isPlaying)
    }

    // MARK: - Runtime assertion

    /// Holds runtime while the audio claim is gone, so queued retries actually run.
    private func beginAssertion() {
        guard assertionID == .invalid else { return }
        // UIKit invokes the expiration handler on the main thread, which is the only
        // queue that touches the recovery state.
        assertionID = UIApplication.shared.beginBackgroundTask(withName: "SilentAudioRecovery") { [weak self] in
            guard let self else { return }
            LogManager.shared.log(
                category: .general,
                message: "Silent audio recovery assertion expired after \(self.attemptsMade) attempts over \(self.elapsedDescription()); the app is about to be suspended without an audio claim"
            )
            self.lastSequenceGaveUp = true
            // A success ends the assertion, so reaching expiration means the claim was
            // never re-established — arm the net without consulting `player.isPlaying`.
            BackgroundRefreshManager.shared.scheduleImmediateRefresh()
            self.cancelRecovery()
        }
    }

    private func endAssertion() {
        guard assertionID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(assertionID)
        assertionID = .invalid
    }

    // MARK: - Helpers

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// `AVAudioSession.ErrorCode` values are four-character codes; the raw number
    /// alone is unreadable in a shared log.
    static func describeSessionError(_ code: Int) -> String {
        switch AVAudioSession.ErrorCode(rawValue: code) {
        case .cannotInterruptOthers: "cannotInterruptOthers"
        case .siriIsRecording: "siriIsRecording"
        case .cannotStartPlaying: "cannotStartPlaying"
        case .cannotStartRecording: "cannotStartRecording"
        case .insufficientPriority: "insufficientPriority"
        case .resourceNotAvailable: "resourceNotAvailable"
        case .mediaServicesFailed: "mediaServicesFailed"
        case .isBusy: "isBusy"
        case .incompatibleCategory: "incompatibleCategory"
        case .expiredSession: "expiredSession"
        case .sessionNotActive: "sessionNotActive"
        case .badParam: "badParam"
        case .none: "unspecified"
        default: "other"
        }
    }
}

extension Notification.Name {
    static let backgroundAudioFailed = Notification.Name("BackgroundAudioFailed")
}
