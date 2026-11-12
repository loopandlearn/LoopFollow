// LoopFollow
// ProfileRemote.swift

import Foundation

/// The profile commands LoopFollow can send.
enum ProfileCommandKind: String, CaseIterable {
    case activate
    case save
    case delete
    case saveScheduledSwitches
}

/// A profile command and what it acts on.
enum ProfileCommand: Equatable {
    case activate(TherapyProfile)
    /// Creates `name` when `original` is nil; otherwise updates `original`, renaming it when `name` differs.
    case save(name: String, original: TherapyProfile?, values: TherapyProfileValues)
    case delete(TherapyProfile)
    /// Replaces the scheduled switches; the phone only does so while its list has `baseFingerprint`.
    case saveScheduledSwitches([ScheduledProfileSwitch], baseFingerprint: String)

    /// The tracker key name of a scheduled switches command, which names no profile.
    static let scheduledSwitchesTarget = "scheduled-switches"

    var kind: ProfileCommandKind {
        switch self {
        case .activate: return .activate
        case .save: return .save
        case .delete: return .delete
        case .saveScheduledSwitches: return .saveScheduledSwitches
        }
    }

    /// The profile named in the phone's reply. For a rename it is the new name.
    var targetName: String {
        switch self {
        case let .activate(profile), let .delete(profile): return profile.name
        case let .save(name, _, _): return name
        case .saveScheduledSwitches: return Self.scheduledSwitchesTarget
        }
    }

    /// True for a save that gives an existing profile a new name.
    var isRename: Bool {
        guard case let .save(name, original?, _) = self else { return false }
        return original.name != name
    }
}

/// The AID app the profile commands go to, with its command names and tracker keys.
enum ProfileRemote: String {
    case loop
    case trio

    var appName: String {
        switch self {
        case .loop: return "Loop"
        case .trio: return "Trio"
        }
    }

    /// Trio doses to one glucose target per time, so its profiles carry a target whose high equals its low.
    var hasSingleTarget: Bool { self == .trio }

    /// The name the app lists in its supported remote commands.
    func commandName(_ kind: ProfileCommandKind) -> String {
        switch (self, kind) {
        case (.loop, .activate): return "profile-switch"
        case (.loop, .save): return "profile-save"
        case (.loop, .delete): return "profile-delete"
        case (.loop, .saveScheduledSwitches): return "profile-scheduled-switches-save"
        case (.trio, .activate): return TRCCommandType.switchProfile.rawValue
        case (.trio, .save): return TRCCommandType.saveProfile.rawValue
        case (.trio, .delete): return TRCCommandType.deleteProfile.rawValue
        case (.trio, .saveScheduledSwitches): return TRCCommandType.saveScheduledSwitches.rawValue
        }
    }

    func supports(_ kind: ProfileCommandKind, in commands: [String]) -> Bool {
        commands.contains(commandName(kind))
    }

    func supportsAny(in commands: [String]) -> Bool {
        ProfileCommandKind.allCases.contains { supports($0, in: commands) }
    }

    /// The commands the app accepts: those in its profile document. Loop builds with the Profile Save & Load
    /// customization list only `profile-switch`, in their device status; they get switches, never saves or deletes.
    /// A Loop that lists commands in its profile document is used through those alone.
    func acceptedCommands(profileDocument: [String], loopDeviceStatus: [String]) -> [String] {
        let activate = commandName(.activate)
        guard self == .loop, loopDeviceStatus.contains(activate), !profileDocument.contains(activate) else {
            return profileDocument
        }
        return profileDocument + [activate]
    }

    func keyPrefix(_ kind: ProfileCommandKind) -> String {
        switch kind {
        case .activate: return "\(rawValue)-profile-switch:"
        case .save: return "\(rawValue)-profile-save:"
        case .delete: return "\(rawValue)-profile-delete:"
        case .saveScheduledSwitches: return "\(rawValue)-profile-scheduled-switches-save:"
        }
    }

    func key(_ kind: ProfileCommandKind, name: String) -> String {
        keyPrefix(kind) + name
    }

    func key(for command: ProfileCommand) -> String {
        key(command.kind, name: command.targetName)
    }

    var keyPrefixes: [String] {
        ProfileCommandKind.allCases.map(keyPrefix)
    }

    /// True for tracker keys of profile commands of either app.
    static func isProfileCommandKey(_ key: String) -> Bool {
        [ProfileRemote.loop, .trio].contains { remote in remote.keyPrefixes.contains { key.hasPrefix($0) } }
    }

    /// Pump programming and both pushes can take a while; a missing reply does not mean the command failed.
    static let timeout: TimeInterval = 180

    var timeoutMessage: String {
        "\(appName) has not replied. The change may still be applied; the list shows it once \(appName) uploads its profiles. Check the list before sending again."
    }

    func successMessage(_ command: ProfileCommand) -> String {
        switch command.kind {
        case .activate: return "Profile '\(command.targetName)' activated"
        case .save: return "Profile '\(command.targetName)' saved"
        case .delete: return "Profile '\(command.targetName)' deleted"
        case .saveScheduledSwitches: return "Scheduled switches saved"
        }
    }

    /// The result of a command whose reply did not arrive, but whose change shows in the uploaded profiles.
    func seenMessage(_ command: ProfileCommand) -> String {
        "\(successMessage(command)). The reply from \(appName) did not arrive, but the profiles \(appName) uploaded to Nightscout show the change."
    }

    func failureMessage(_ command: ProfileCommand) -> String {
        switch command.kind {
        case .activate: return "Profile '\(command.targetName)' not activated"
        case .save: return "Profile '\(command.targetName)' not saved"
        case .delete: return "Profile '\(command.targetName)' not deleted"
        case .saveScheduledSwitches: return "Scheduled switches not saved"
        }
    }
}
