// LoopFollow
// ProfileEditorSheet.swift

import SwiftUI

enum ProfileEditing {
    /// Why profiles of this set can not be edited remotely, or nil when they can.
    static func blocker(limits: ProfileEditLimits?, remote: ProfileRemote) -> String? {
        guard let limits else {
            let missing = "\(remote.appName) has not shared the limits LoopFollow needs to change profiles safely, so profiles can only be viewed here."
            switch remote {
            case .loop:
                return missing + " Loop shares them once a pump and a maximum basal rate are set up in it; an older version of Loop may need an update first."
            case .trio:
                return missing + " An older version of Trio may need an update first."
            }
        }
        guard limits.isUsable else {
            return "The limits \(remote.appName) shared are incomplete, so profiles can only be viewed here."
        }
        return nil
    }

    /// Why this profile can not be edited remotely, or nil when it can.
    static func blocker(for profile: TherapyProfile, limits: ProfileEditLimits?, remote: ProfileRemote) -> String? {
        if let blocker = blocker(limits: limits, remote: remote) { return blocker }
        if let limits, profile.values.units != limits.normalizedUnits {
            return "This profile is stored in \(profile.values.units), but \(remote.appName) shared its limits in \(limits.normalizedUnits). Change it in \(remote.appName) instead."
        }
        if !profile.isWellFormed {
            return "The correction range of this profile could not be read completely. Change it in \(remote.appName) instead."
        }
        return nil
    }
}

/// Creates a profile from an existing one, or edits one, and leads to the review before sending.
struct ProfileEditorSheet: View {
    enum Mode: Equatable {
        case new(source: TherapyProfile)
        case edit(TherapyProfile)
    }

    let remote: ProfileRemote
    let mode: Mode
    let profileSet: TherapyProfileSet
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var source: TherapyProfile
    @State private var draft: ProfileDraft

    init(remote: ProfileRemote, mode: Mode, profileSet: TherapyProfileSet, onFinished: @escaping () -> Void) {
        self.remote = remote
        self.mode = mode
        self.profileSet = profileSet
        self.onFinished = onFinished
        let source: TherapyProfile
        switch mode {
        case let .new(start): source = start
        case let .edit(profile): source = profile
        }
        _source = State(initialValue: source)
        _name = State(initialValue: "")
        _draft = State(initialValue: ProfileDraft(source.values, singleTarget: remote.hasSingleTarget))
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var limits: ProfileEditLimits? { profileSet.limits }

    private var blocker: String? {
        ProfileEditing.blocker(for: source, limits: limits, remote: remote)
    }

    private var editableLimits: ProfileEditLimits? {
        blocker == nil ? limits : nil
    }

    private var targetName: String {
        isNew ? ProfileValidation.normalizedName(name) : source.name
    }

    private var nameProblem: String? {
        guard isNew else { return nil }
        return ProfileValidation.countProblem(profileCount: profileSet.profiles.count)
            ?? ProfileValidation.nameProblem(name, existingNames: profileSet.profiles.map(\.name))
    }

    private var problems: [String] {
        guard let limits = editableLimits else { return [] }
        return ProfileValidation.problems(draft.values, limits: limits)
    }

    private var hasChanges: Bool {
        draft.values != ProfileDraft(source.values, singleTarget: remote.hasSingleTarget).values
    }

    private var isEditingActive: Bool {
        !isNew && profileSet.isActive(source)
    }

    private var canReview: Bool {
        editableLimits != nil && nameProblem == nil && problems.isEmpty && (isNew || hasChanges)
    }

    private var command: ProfileCommand {
        .save(name: targetName, original: isNew ? nil : source, values: draft.values)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let blocker {
                    Section {
                        Label(blocker, systemImage: "lock")
                            .foregroundColor(.secondary)
                    }
                }

                if isEditingActive {
                    Section {
                        ActiveProfileWarning(remote: remote)
                    }
                }

                if isNew {
                    Section(header: Text("Name"), footer: nameFooter) {
                        TextField("Profile name", text: $name)
                            .autocorrectionDisabled()
                    }
                    Section(header: Text("Start From"), footer: Text("The new profile starts with a copy of these values. Choosing another profile discards changes made below.")) {
                        Picker("Profile", selection: Binding(
                            get: { source.name },
                            set: { newName in
                                guard let profile = profileSet.profile(named: newName) else { return }
                                source = profile
                                draft = ProfileDraft(profile.values, singleTarget: remote.hasSingleTarget)
                            }
                        )) {
                            ForEach(profileSet.profiles) { profile in
                                Text(profile.name).tag(profile.name)
                            }
                        }
                    }
                }

                ForEach(ProfileScheduleKind.allCases) { kind in
                    ProfileValuesEditor(kind: kind, segments: Binding(get: { draft[kind] }, set: { draft[kind] = $0 }), units: draft.units, limits: editableLimits, singleTarget: remote.hasSingleTarget)
                }

                if !problems.isEmpty {
                    Section(header: Text("Fix Before Sending")) {
                        ForEach(problems, id: \.self) { problem in
                            Text(problem).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Profile" : "Edit \(source.name)")
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
                            baseline: source,
                            isActive: isEditingActive,
                            limits: editableLimits,
                            onFinished: onFinished
                        )
                    }
                    .disabled(!canReview)
                }
            }
        }
        .interactiveDismissDisabled(hasChanges || !name.isEmpty)
    }

    private var nameFooter: some View {
        Group {
            if let nameProblem, !name.isEmpty {
                Text(nameProblem).foregroundColor(.red)
            } else {
                Text("Up to \(ProfileValidation.maxNameLength) characters. Not “Default”, no period (.), and not starting with $.")
            }
        }
    }
}
