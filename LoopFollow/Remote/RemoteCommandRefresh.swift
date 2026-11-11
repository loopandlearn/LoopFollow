// LoopFollow
// RemoteCommandRefresh.swift

import Foundation
import HealthKit

/// Loop and Trio apply a remote command within seconds, but LoopFollow only sees
/// the result on its next regular Nightscout fetch, which can be minutes away.
/// After a command is sent, treatments and device status (the profile document for
/// a profile command) are fetched a few extra times, stopping as soon as the change
/// the command makes shows up, so the new override, temp target, bolus, carbs or
/// profile reach the phone, the watch and the Live Activity sooner.
final class RemoteCommandRefresh {
    /// What a command changes, and so what ends the follow-up fetches.
    enum Change {
        case override
        case tempTarget
        case bolus(units: Double)
        /// A bolus sent with the meal (Trio) also has to show up; 0 g of carbs
        /// (fat and protein only) matches any new carb entry.
        case meal(grams: Double, bolus: Double)
        case profile(ProfileCommand)

        var name: String {
            switch self {
            case .override: "override"
            case .tempTarget: "temp target"
            case .bolus: "bolus"
            case .meal: "meal"
            case .profile: "profile change"
            }
        }

        var tasks: [TaskID] {
            switch self {
            case .profile: [.profile]
            default: [.treatments, .deviceStatus]
            }
        }
    }

    static let shared = RemoteCommandRefresh()

    /// Seconds after the send. Most uploads land in the first half minute; the
    /// later fetches cover a pump that is slow to deliver or an upload that is retried.
    static let delays: [TimeInterval] = [10, 20, 30, 60, 90, 120]

    private var pending: DispatchWorkItem?
    private var pendingIsProfile = false

    private init() {}

    /// Wraps a send's completion so that a successful send starts the follow-up fetches.
    static func following(_ change: Change, _ completion: @escaping (Bool, String?) -> Void) -> (Bool, String?) -> Void {
        { success, error in
            if success { shared.commandSent(change) }
            completion(success, error)
        }
    }

    /// Restarts the follow-up fetches; a newer command replaces the remaining ones.
    func commandSent(_ change: Change) {
        DispatchQueue.main.async {
            self.cancel()
            LogManager.shared.log(category: .apns, message: "Fetching Nightscout early until the \(change.name) shows up")
            self.schedule(step: 0, after: Self.delays[0], arrived: Self.arrivalCheck(for: change), change: change)
        }
    }

    /// A profile command's reply: the phone uploads its profiles before replying, so the profile
    /// document is fetched now, and a refused command ends the follow-up fetches.
    func profileCommandAnswered(success: Bool) {
        DispatchQueue.main.async {
            if !success, self.pendingIsProfile { self.cancel() }
            TaskScheduler.shared.rescheduleTask(id: .profile, to: Date())
        }
    }

    /// Each fetch schedules the next one, so when the app was suspended past
    /// several of them (Bluetooth heartbeat modes), it fetches once on resuming
    /// instead of all the overdue ones at once.
    private func schedule(step: Int, after delay: TimeInterval, arrived: @escaping () -> Bool, change: Change) {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if arrived() {
                LogManager.shared.log(category: .apns, message: "The \(change.name) showed up; \(Self.delays.count - step) early fetches skipped")
                self.cancel()
                if case let .profile(command) = change {
                    RemoteCommandTracker.shared.resolveProfileCommandSeen(command)
                }
                return
            }
            for task in change.tasks {
                TaskScheduler.shared.rescheduleTask(id: task, to: Date())
            }
            let next = step + 1
            guard next < Self.delays.count else {
                self.cancel()
                return
            }
            self.schedule(step: next, after: Self.delays[next] - Self.delays[step], arrived: arrived, change: change)
        }
        pending = work
        if case .profile = change { pendingIsProfile = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancel() {
        pending?.cancel()
        pending = nil
        pendingIsProfile = false
    }

    /// Captures the phone's data now and returns a check that is true once the
    /// command's change is in it. A change that never matches (a partial bolus,
    /// a renamed preset) only means the fetches run their full two minutes.
    private static func arrivalCheck(for change: Change) -> () -> Bool {
        switch change {
        case .override:
            let before = (Observable.shared.override.value, Observable.shared.overrideEndAt.value)
            return { (Observable.shared.override.value, Observable.shared.overrideEndAt.value) != before }
        case .tempTarget:
            // Compared as numbers: each treatments fetch creates a new HKQuantity.
            func current() -> (Double?, TimeInterval?) {
                (Observable.shared.tempTarget.value?.doubleValue(for: .milligramsPerDeciliter), Observable.shared.tempTargetEndAt.value)
            }
            let before = current()
            return { current() != before }
        case let .bolus(units):
            return newEntry(in: boluses, matching: units, tolerance: 0.01)
        case let .meal(grams, bolus):
            let carbsArrived = newEntry(in: carbs, matching: grams > 0 ? grams : nil, tolerance: 0.5)
            guard bolus > 0 else { return carbsArrived }
            let bolusArrived = newEntry(in: boluses, matching: bolus, tolerance: 0.01)
            return { carbsArrived() && bolusArrived() }
        case let .profile(command):
            let before = Observable.shared.therapyProfiles.value
            return { profileArrived(command, before: before, now: Observable.shared.therapyProfiles.value) }
        }
    }

    /// True once `now` shows the command's result: the profile is active, deleted, or saved with
    /// values other than those in `before` (a new or renamed profile has none there), or the scheduled switches
    /// are no longer the list the command replaced.
    static func profileArrived(_ command: ProfileCommand, before: TherapyProfileSet?, now: TherapyProfileSet?) -> Bool {
        guard let now else { return false }
        switch command {
        case let .activate(profile):
            return now.activeName.caseInsensitiveCompare(profile.name) == .orderedSame
        case let .delete(profile):
            return now.profile(named: profile.name) == nil
        case let .save(name, _, _):
            guard let saved = now.profile(named: name) else { return false }
            return saved.fingerprint != before?.profile(named: name)?.fingerprint
        case let .saveScheduledSwitches(_, baseFingerprint):
            return now.scheduledSwitches.fingerprint != baseFingerprint
        }
    }

    /// True once an entry that was not there at the send appears, with `value` when given.
    private static func newEntry(
        in entries: @escaping () -> [(date: TimeInterval, value: Double)],
        matching value: Double?,
        tolerance: Double
    ) -> () -> Bool {
        let known = Set(entries().map { $0.date })
        return {
            entries().contains { entry in
                !known.contains(entry.date) && value.map { abs(entry.value - $0) < tolerance } ?? true
            }
        }
    }

    private static func boluses() -> [(date: TimeInterval, value: Double)] {
        let vc = MainViewController.shared
        return ((vc?.bolusData ?? []) + (vc?.smbData ?? [])).map { (date: $0.date, value: $0.value) }
    }

    private static func carbs() -> [(date: TimeInterval, value: Double)] {
        (MainViewController.shared?.carbData ?? []).map { (date: $0.date, value: $0.value) }
    }
}
