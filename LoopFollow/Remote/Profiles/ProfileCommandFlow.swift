// LoopFollow
// ProfileCommandFlow.swift

import SwiftUI

/// Device authentication and sending for profile commands. The result arrives through the tracker state.
enum ProfileCommandFlow {
    static func authenticateAndSend(
        _ command: ProfileCommand,
        to remote: ProfileRemote,
        reason: String,
        onFailure: @escaping (String) -> Void
    ) {
        AuthService.authenticate(reason: reason) { result in
            switch result {
            case .success:
                RemoteCommandTracker.shared.sendProfileCommand(command, to: remote) { success, error in
                    if !success {
                        LogManager.shared.log(category: .apns, message: "Profile command not sent: \(error ?? "unknown error")")
                    }
                }
            case let .unavailable(message):
                onFailure(message)
            case .failed:
                onFailure("Authentication failed")
            case .canceled:
                break
            }
        }
    }

    static func resultTitle(kind: ProfileCommandKind, success: Bool, message: String, remote: ProfileRemote) -> String {
        if message == remote.timeoutMessage { return "No Reply From \(remote.appName)" }
        switch (kind, success) {
        case (.activate, true): return "Profile Activated"
        case (.activate, false): return "Profile Not Activated"
        case (.save, true): return "Profile Saved"
        case (.save, false): return "Profile Not Saved"
        case (.delete, true): return "Profile Deleted"
        case (.delete, false): return "Profile Not Deleted"
        case (.saveScheduledSwitches, true): return "Scheduled Switches Saved"
        case (.saveScheduledSwitches, false): return "Scheduled Switches Not Saved"
        }
    }

    /// True when the screen that sent the command closes after the result: on success; when no reply came,
    /// because the change may have been applied; and when the profile changed or is gone on the phone, because
    /// the screen's values are out of date. The profile list then shows the uploaded profiles. Any other refusal
    /// keeps the screen open so the values can be corrected.
    static func leavesAfterResult(_ result: ProfileCommandResult, remote: ProfileRemote) -> Bool {
        result.success || result.outdated || result.message == remote.timeoutMessage
    }

    /// The reply text, with a note on what happens next when the profile was out of date.
    static func resultMessage(_ result: ProfileCommandResult, remote: ProfileRemote) -> String {
        guard result.outdated else { return result.message }
        return result.message + "\n\nLoopFollow is loading the profiles \(remote.appName) uploaded. Open the profile again to see its current values."
    }

    /// Loads the newest profile document from Nightscout. Completes on the main queue, with nil when it can not be loaded.
    static func fetchProfileSet(completion: @escaping (TherapyProfileSet?) -> Void) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parameters = ["count": "1", "find[startDate][$lte]": formatter.string(from: Date().addingTimeInterval(60))]
        NightscoutUtils.executeRequest(eventType: .profile, parameters: parameters) { (result: Result<[NSProfile], Error>) in
            let profileSet = (try? result.get())?.first.map(TherapyProfileSet.init)
            DispatchQueue.main.async { completion(profileSet) }
        }
    }

    /// Why a save of `original`, reviewed while it was `reviewedActive`, must not be sent now that `current` is the
    /// newest profile document, or nil when it can be sent.
    static func saveStaleReason(original: TherapyProfile, reviewedActive: Bool, current: TherapyProfileSet?, remote: ProfileRemote) -> String? {
        guard let current else {
            return "LoopFollow could not load the profiles from Nightscout to check that “\(original.name)” is unchanged, so nothing was sent. Try again."
        }
        guard let profile = current.profile(named: original.name) else {
            return "“\(original.name)” is no longer in the list uploaded by \(remote.appName), so nothing was sent."
        }
        if profile.fingerprint != original.fingerprint {
            return "“\(original.name)” changed in \(remote.appName) while you were editing, so nothing was sent. Review it again."
        }
        if current.isActive(profile) != reviewedActive {
            return reviewedActive
                ? "“\(original.name)” is no longer the active profile in \(remote.appName), so nothing was sent. Review it again."
                : "“\(original.name)” became active in \(remote.appName) while you were editing, so nothing was sent. Review it again."
        }
        return nil
    }

    /// The tracker keys of all profile commands for this app.
    static func isAnyPending(_ tracker: RemoteCommandTracker, remote: ProfileRemote) -> Bool {
        tracker.isBusy(keyPrefixes: remote.keyPrefixes)
    }
}

/// The outcome of a profile command as the tracker reports it.
struct ProfileCommandResult: Equatable {
    let success: Bool
    let message: String
    /// The phone refused because the profile changed or no longer exists there.
    var outdated = false
}

/// Reports a finished profile command once, also when the view was left while it was pending.
struct ProfileCommandResultModifier: ViewModifier {
    let keys: [String]
    /// When set, the result of another command sent under the same key is dropped without a report.
    let command: ProfileCommand?
    let onResult: (String, ProfileCommandResult) -> Void

    @ObservedObject private var tracker = RemoteCommandTracker.shared

    func body(content: Content) -> some View {
        content
            .onAppear { keys.forEach(check) }
            .onChange(of: keys.map { tracker.states[$0] }) { _, _ in keys.forEach(check) }
    }

    private func check(_ key: String) {
        guard case let .done(success, message, outdated) = tracker.states[key] else { return }
        tracker.consume(key: key)
        if let command, tracker.profileCommands[key] != command { return }
        // A result that arrives at once comes while the confirmation alert is still closing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onResult(key, ProfileCommandResult(success: success, message: message, outdated: outdated))
        }
    }
}

extension View {
    func onProfileCommandResult(
        keys: [String],
        command: ProfileCommand? = nil,
        perform: @escaping (String, ProfileCommandResult) -> Void
    ) -> some View {
        modifier(ProfileCommandResultModifier(keys: keys, command: command, onResult: perform))
    }
}

/// The note shown where profiles are introduced and before a change is sent.
struct ProfileDosingNote: View {
    var body: some View {
        Text("Profiles hold the settings used to dose insulin.")
    }
}

/// Lists where a profile gives more insulin than the one it is compared with.
struct MoreInsulinWarning: View {
    let increases: [ProfileInsulinIncrease]
    let basalTotal: (old: Double, new: Double)?
    /// The profile the values are compared with.
    let comparedWith: String
    /// True when dosing changes as soon as the command arrives.
    let appliesNow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("More insulin than “\(comparedWith)”")
                    .font(.callout.weight(.semibold))
            } icon: {
                Image(systemName: "arrow.up.circle.fill")
            }
            .foregroundColor(.red)
            ForEach(increases) { increase in
                Text("• \(increase.text)")
            }
            if let basalTotal {
                Text("• Basal per day \(Self.units(basalTotal.old)) → \(Self.units(basalTotal.new)) U")
            }
            Text(appliesNow
                ? "More insulin raises the risk of lows. Check that these values are what was agreed, and watch glucose closely after sending."
                : "More insulin raises the risk of lows once this profile is active. Check that these values are what was agreed.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    static func units(_ value: Double) -> String {
        Localizer.formatToLocalizedString(value, maxFractionDigits: 2, minFractionDigits: 2)
    }

    /// One sentence for a confirmation alert, empty when nothing gives more insulin.
    static func sentence(_ increases: [ProfileInsulinIncrease], comparedWith: String) -> String {
        guard !increases.isEmpty else { return "" }
        return "\n\nThis gives more insulin than “\(comparedWith)”: \(increases.map(\.text).joined(separator: "; "))."
    }
}

/// The warning shown when a change applies to the profile that is in use.
struct ActiveProfileWarning: View {
    let remote: ProfileRemote

    var body: some View {
        Label {
            Text("This is the active profile. Saving changes insulin dosing right away: \(remote.appName) sends the new basal rates to the pump and starts using all new values as soon as it gets the command.")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundColor(.red)
        .font(.callout.weight(.semibold))
    }
}
