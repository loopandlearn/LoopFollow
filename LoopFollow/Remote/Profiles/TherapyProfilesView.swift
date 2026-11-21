// LoopFollow
// TherapyProfilesView.swift

import SwiftUI

/// Lists the profiles of Loop or Trio. Selecting one shows its values, where it can be activated, edited,
/// renamed or deleted, as far as the app supports those commands.
struct TherapyProfilesView: View {
    let remote: ProfileRemote

    @ObservedObject private var therapyProfiles = Observable.shared.therapyProfiles
    @ObservedObject private var remoteCommands = Storage.shared.remoteCommands
    @ObservedObject private var loopRemoteCommands = Storage.shared.loopRemoteCommands
    @State private var sheet: ListSheet?

    /// A sheet opened from the list. It keeps the profiles it was opened with, and is attached to the list itself,
    /// so it stays open with its result alert while the profiles are reloaded.
    private struct ListSheet: Identifiable {
        enum Kind {
            case newProfile(source: TherapyProfile)
            case scheduledSwitches
            case pause(entries: [ScheduledProfileSwitch])
        }

        let kind: Kind
        let profileSet: TherapyProfileSet
        let id = UUID()
    }

    private var commands: [String] {
        remote.acceptedCommands(profileDocument: remoteCommands.value, loopDeviceStatus: loopRemoteCommands.value)
    }

    private var canSave: Bool { remote.supports(.save, in: commands) }

    /// Default is a real profile once the app can save profiles. Older Loop builds upload a Default entry that
    /// only mirrors the active settings, so it is left out for them.
    private func visibleProfiles(_ set: TherapyProfileSet) -> [TherapyProfile] {
        canSave ? set.profiles : set.profiles.filter { !$0.isDefault }
    }

    var body: some View {
        List {
            Section {
                ProfileDosingNote()
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let profileSet = therapyProfiles.value, !visibleProfiles(profileSet).isEmpty {
                Section(
                    header: Text("Profiles"),
                    footer: uploadedFooter(profileSet.uploadedAt)
                ) {
                    ForEach(visibleProfiles(profileSet)) { profile in
                        NavigationLink(destination: TherapyProfilePreviewView(remote: remote, name: profile.name)) {
                            HStack {
                                Text(profile.name)
                                Spacer()
                                if profileSet.isActive(profile) {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }

                ScheduledSwitchesSection(
                    remote: remote,
                    profileSet: profileSet,
                    commands: commands,
                    onEdit: { sheet = ListSheet(kind: .scheduledSwitches, profileSet: profileSet) },
                    onTogglePause: { sheet = ListSheet(kind: .pause(entries: $0), profileSet: profileSet) }
                )

                if canSave {
                    let createBlocker = ProfileEditing.blocker(limits: profileSet.limits, remote: remote) ?? ProfileValidation.countProblem(profileCount: profileSet.profiles.count)
                    Section(footer: Text(createBlocker ?? "A new profile starts as a copy of the active profile. Dosing does not change until it is activated.")) {
                        Button {
                            if let source = profileSet.activeProfile ?? profileSet.profiles.first {
                                sheet = ListSheet(kind: .newProfile(source: source), profileSet: profileSet)
                            }
                        } label: {
                            Label("New Profile", systemImage: "plus")
                        }
                        .disabled(createBlocker != nil || profileSet.profiles.isEmpty)
                    }
                }
            } else {
                Text(remote == .loop
                    ? "No saved profiles found. Profiles are saved in Loop under Settings → Profiles."
                    : "No profiles found. Profiles are saved in Trio under Settings → Therapy Settings → Therapy Profiles.")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .navigationBarTitle("Remote Profiles", displayMode: .inline)
        .sheet(item: $sheet) { sheet in
            switch sheet.kind {
            case let .newProfile(source):
                ProfileEditorSheet(remote: remote, mode: .new(source: source), profileSet: sheet.profileSet) {
                    self.sheet = nil
                }
            case .scheduledSwitches:
                ScheduledSwitchesEditorSheet(remote: remote, profileSet: sheet.profileSet) { self.sheet = nil }
            case let .pause(entries):
                NavigationStack {
                    ScheduledSwitchesReviewView(remote: remote, profileSet: sheet.profileSet, entries: entries) { self.sheet = nil }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { self.sheet = nil }
                            }
                        }
                }
            }
        }
    }

    private func uploadedFooter(_ date: Date?) -> Text {
        guard let date else { return Text("") }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return Text("Uploaded by \(remote.appName) \(formatter.string(from: date)).")
    }
}

/// Shows a profile's values. From here it can be activated, edited, renamed or deleted.
struct TherapyProfilePreviewView: View {
    let remote: ProfileRemote
    let name: String

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var therapyProfiles = Observable.shared.therapyProfiles
    @ObservedObject private var remoteCommands = Storage.shared.remoteCommands
    @ObservedObject private var loopRemoteCommands = Storage.shared.loopRemoteCommands
    @ObservedObject private var tracker = RemoteCommandTracker.shared
    @State private var alertType: AlertType?
    @State private var sheet: ProfileSheet?

    /// An edit or rename of the profile. It keeps the profile and profiles it was opened with, and is attached
    /// outside the profile's values, so it stays open with its result alert while the profiles are reloaded,
    /// also when the profile is renamed.
    private struct ProfileSheet: Identifiable {
        enum Kind { case edit, rename }

        let kind: Kind
        let profile: TherapyProfile
        let profileSet: TherapyProfileSet
        let id = UUID()
    }

    private enum AlertType: Identifiable {
        /// The confirmations carry the fingerprint of the profile they show.
        case confirmActivate(fingerprint: String)
        case confirmDelete(fingerprint: String)
        case result(kind: ProfileCommandKind, ProfileCommandResult)

        var id: String {
            switch self {
            case let .confirmActivate(fingerprint): return "activate-\(fingerprint)"
            case let .confirmDelete(fingerprint): return "delete-\(fingerprint)"
            case let .result(kind, result): return "result-\(kind)-\(result.success)-\(result.message)"
            }
        }
    }

    private var commands: [String] {
        remote.acceptedCommands(profileDocument: remoteCommands.value, loopDeviceStatus: loopRemoteCommands.value)
    }

    private var profileSet: TherapyProfileSet? { therapyProfiles.value }

    private var profile: TherapyProfile? { profileSet?.profile(named: name) }

    private var isActive: Bool {
        guard let profile, let profileSet else { return false }
        return profileSet.isActive(profile)
    }

    /// The active profile, when this profile gives more insulin than it somewhere.
    private var activationIncreases: (active: TherapyProfile, increases: [ProfileInsulinIncrease])? {
        guard !isActive, let profile, let active = profileSet?.activeProfile else { return nil }
        let increases = ProfileInsulinComparison.increases(from: active.values, to: profile.values)
        return increases.isEmpty ? nil : (active, increases)
    }

    private var activateKey: String { remote.key(.activate, name: name) }
    private var deleteKey: String { remote.key(.delete, name: name) }

    private var resultKeys: [String] {
        [activateKey, deleteKey]
    }

    private var anyPending: Bool { ProfileCommandFlow.isAnyPending(tracker, remote: remote) }

    private var editBlocker: String? {
        guard let profile else { return nil }
        return ProfileEditing.blocker(for: profile, limits: profileSet?.limits, remote: remote)
    }

    var body: some View {
        Group {
            if let profile {
                content(profile)
            } else {
                Text("This profile is no longer in the list uploaded by \(remote.appName).")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationBarTitle(name, displayMode: .inline)
        .onProfileCommandResult(keys: resultKeys) { key, result in
            let kind: ProfileCommandKind = key == activateKey ? .activate : .delete
            alertType = .result(kind: kind, result)
        }
        .alert(item: $alertType) { type in alert(type) }
        .sheet(item: $sheet) { sheet in
            switch sheet.kind {
            case .edit:
                ProfileEditorSheet(remote: remote, mode: .edit(sheet.profile), profileSet: sheet.profileSet) {
                    self.sheet = nil
                }
            case .rename:
                ProfileRenameSheet(remote: remote, profile: sheet.profile, profileSet: sheet.profileSet, isActive: sheet.profileSet.isActive(sheet.profile)) {
                    self.sheet = nil
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func open(_ kind: ProfileSheet.Kind, _ profile: TherapyProfile) {
        guard let profileSet else { return }
        sheet = ProfileSheet(kind: kind, profile: profile, profileSet: profileSet)
    }

    private func content(_ profile: TherapyProfile) -> some View {
        List {
            Section(footer: Text("\(remote.appName) writes the basal rates to the pump when the profile is activated.")) {
                Text(isActive ? "This is the active profile. \(remote.appName) doses insulin with these values." : "Review the profile before activating it in \(remote.appName).")
                if let activationIncreases {
                    MoreInsulinWarning(
                        increases: activationIncreases.increases,
                        basalTotal: ProfileInsulinComparison.basalTotalIncrease(from: activationIncreases.active.values, to: profile.values),
                        comparedWith: activationIncreases.active.name,
                        appliesNow: true
                    )
                }
            }

            ForEach(ProfileScheduleKind.allCases) { kind in
                ProfileValuesEditor(
                    kind: kind,
                    segments: .constant(ProfileDraft(profile.values, singleTarget: remote.hasSingleTarget)[kind]),
                    units: profile.values.units,
                    limits: nil,
                    singleTarget: remote.hasSingleTarget
                )
            }

            if remote.supports(.save, in: commands) || remote.supports(.delete, in: commands) {
                actionsSection(profile)
            }
        }
        .toolbar {
            if remote.supports(.save, in: commands) {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { open(.edit, profile) }
                        .disabled(editBlocker != nil || anyPending)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if remote.supports(.activate, in: commands) {
                activateButton
            }
        }
    }

    @ViewBuilder
    private func actionsSection(_ profile: TherapyProfile) -> some View {
        let canDelete = remote.supports(.delete, in: commands) && !isActive && !profile.isDefault
        Section(footer: actionsFooter(profile)) {
            if remote.supports(.save, in: commands), !profile.isDefault {
                Button("Rename Profile") { open(.rename, profile) }
                    .disabled(editBlocker != nil || anyPending)
            }
            if remote.supports(.delete, in: commands), !profile.isDefault, !isActive {
                Button("Delete Profile", role: .destructive) { alertType = .confirmDelete(fingerprint: profile.fingerprint) }
                    .disabled(!canDelete || anyPending)
            }
        }
    }

    private func actionsFooter(_ profile: TherapyProfile) -> Text {
        if let editBlocker, remote.supports(.save, in: commands) { return Text(editBlocker) }
        if profile.isDefault { return Text("The Default profile always exists. It can be edited, but not renamed or deleted.") }
        if isActive { return Text("The active profile can't be deleted. Activate another profile first.") }
        return Text("")
    }

    private var activateButton: some View {
        let isSending = tracker.isBusy(key: activateKey)
        return Button {
            if let profile { alertType = .confirmActivate(fingerprint: profile.fingerprint) }
        } label: {
            Group {
                if isSending {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for \(remote.appName)...")
                    }
                } else if anyPending {
                    Text("Another Profile Command Is Pending")
                } else {
                    Text(isActive ? "Active Profile" : "Activate Profile")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isActive || anyPending)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func alert(_ type: AlertType) -> Alert {
        switch type {
        case let .confirmActivate(fingerprint):
            return Alert(
                title: Text("Activate \(name) in \(remote.appName)?"),
                message: Text("\(remote.appName) replaces its correction range, carb ratios, basal rates and insulin sensitivities with these values and writes the basal rates to the pump. Dosing changes right away."
                    + (profileSet.flatMap { ScheduledSwitches.holdText($0.scheduledSwitches) }.map { " " + $0 } ?? "")
                    + MoreInsulinWarning.sentence(activationIncreases?.increases ?? [], comparedWith: activationIncreases?.active.name ?? "")),
                primaryButton: .default(Text("Activate")) { send(.activate, fingerprint: fingerprint) },
                secondaryButton: .cancel()
            )
        case let .confirmDelete(fingerprint):
            return Alert(
                title: Text("Delete \(name)?"),
                message: Text("\(remote.appName) removes this profile. This can't be undone from LoopFollow."
                    + (profileSet.flatMap { ScheduledSwitches.deletionText($0.scheduledSwitches, profileName: name) }.map { " " + $0 } ?? "")),
                primaryButton: .destructive(Text("Delete")) { send(.delete, fingerprint: fingerprint) },
                secondaryButton: .cancel()
            )
        case let .result(kind, result):
            return Alert(
                title: Text(ProfileCommandFlow.resultTitle(kind: kind, success: result.success, message: result.message, remote: remote)),
                message: Text(ProfileCommandFlow.resultMessage(result, remote: remote)),
                dismissButton: .default(Text("OK")) {
                    if ProfileCommandFlow.leavesAfterResult(result, remote: remote) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }

    private func send(_ kind: ProfileCommandKind, fingerprint: String) {
        guard let profile else { return }
        guard profile.fingerprint == fingerprint else {
            let message = "\(name) changed while the confirmation was open, so nothing was sent. Review it again."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alertType = .result(kind: kind, ProfileCommandResult(success: false, message: message))
            }
            return
        }
        let command: ProfileCommand = kind == .delete ? .delete(profile) : .activate(profile)
        let verb = kind == .delete ? "delete" : "activate"
        ProfileCommandFlow.authenticateAndSend(command, to: remote, reason: "Confirm your identity to \(verb) \(profile.name) in \(remote.appName).") { message in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alertType = .result(kind: kind, ProfileCommandResult(success: false, message: message))
            }
        }
    }
}

/// Renames a profile: a save of its unchanged values under the new name, reviewed before sending.
struct ProfileRenameSheet: View {
    let remote: ProfileRemote
    let profile: TherapyProfile
    let profileSet: TherapyProfileSet
    let isActive: Bool
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var problem: String? {
        if ProfileValidation.normalizedName(name) == profile.name { return "Enter a new name." }
        return ProfileValidation.nameProblem(name, existingNames: profileSet.profiles.map(\.name), originalName: profile.name)
    }

    private var command: ProfileCommand {
        .save(name: ProfileValidation.normalizedName(name), original: profile, values: profile.values)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Name"), footer: footer) {
                    TextField(profile.name, text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Rename \(profile.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink("Review") {
                        ProfileReviewView(
                            remote: remote,
                            command: command,
                            baseline: profile,
                            isActive: isActive,
                            limits: profileSet.limits,
                            onFinished: onFinished
                        )
                    }
                    .disabled(problem != nil)
                }
            }
        }
    }

    private var footer: some View {
        Group {
            if let problem, !name.isEmpty {
                Text(problem).foregroundColor(.red)
            } else {
                Text("The values stay the same\(isActive ? " and the profile stays active" : ""). Up to \(ProfileValidation.maxNameLength) characters, not “Default”, no period (.), and not starting with $.")
            }
        }
    }
}
