// LoopFollow
// ScheduledSwitchesView.swift

import SwiftUI

enum ScheduledSwitchEditing {
    /// Why the scheduled switches can not be changed from LoopFollow, or nil when they can.
    static func blocker(_ list: ScheduledSwitchList, supported: Bool, remote: ProfileRemote) -> String? {
        guard supported else {
            return "\(remote.appName) has not said it accepts changes to its scheduled switches from LoopFollow, so they can only be viewed here. An older version of \(remote.appName) may need an update first."
        }
        guard list.isComplete else {
            return "The scheduled switches \(remote.appName) uploaded could not be read completely, so they can only be viewed here. Change them in \(remote.appName) instead."
        }
        return nil
    }
}

/// The note shown with the scheduled switches and before a change to them is sent.
struct ScheduledSwitchDosingNote: View {
    var body: some View {
        Text("A scheduled switch changes the profile that doses insulin at the set time, also when nobody is looking at the phone.")
    }
}

/// One start in the week, with how long its profile stays active.
struct ScheduledSwitchRow: View {
    let entry: ScheduledProfileSwitch
    let entries: [ScheduledProfileSwitch]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(ScheduledSwitches.slotText(entry, short: true)) · \(entry.profile) starts")
                .foregroundColor(entry.paused ? .secondary : .primary)
            Text(ScheduledSwitches.spanText(entry, in: entries))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The scheduled switches section of the profile list: the week with pause and resume per start, and the button
/// for the editor. The list presents the editor and the review of a pause or resume.
struct ScheduledSwitchesSection: View {
    let remote: ProfileRemote
    let profileSet: TherapyProfileSet
    let commands: [String]
    let onEdit: () -> Void
    /// Called with the whole list after pausing or resuming one start, for review before sending.
    let onTogglePause: ([ScheduledProfileSwitch]) -> Void

    @ObservedObject private var tracker = RemoteCommandTracker.shared

    private var list: ScheduledSwitchList { profileSet.scheduledSwitches }
    private var supported: Bool { remote.supports(.saveScheduledSwitches, in: commands) }
    private var blocker: String? { ScheduledSwitchEditing.blocker(list, supported: supported, remote: remote) }
    private var anyPending: Bool { ProfileCommandFlow.isAnyPending(tracker, remote: remote) }
    private var canChange: Bool { blocker == nil && !anyPending }

    var body: some View {
        if supported || !list.entries.isEmpty {
            Section(header: Text("Scheduled Switches"), footer: footer) {
                ForEach(ScheduledSwitches.sortedForWeek(list.entries)) { entry in
                    ScheduledSwitchRow(entry: entry, entries: list.entries)
                        .swipeActions(edge: .trailing) {
                            if canChange {
                                Button(entry.paused ? "Resume" : "Pause") { togglePause(entry) }
                                    .tint(entry.paused ? .green : .orange)
                            }
                        }
                }
                if supported {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Scheduled Switches", systemImage: "calendar")
                    }
                    .disabled(!canChange)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ScheduledSwitches.footerText(list, appName: remote.appName))
            if let note = ScheduledSwitches.timeZoneNote(list.timeZone) {
                Text(note)
            }
            if let blocker {
                Text(blocker)
            } else if !list.entries.isEmpty {
                Text("Swipe left on a start to pause or resume it.")
            }
        }
    }

    private func togglePause(_ entry: ScheduledProfileSwitch) {
        onTogglePause(ScheduledSwitches.togglingPause(of: entry.id, in: list.entries))
    }
}

/// Edits the whole list of scheduled switches and leads to the review before sending.
struct ScheduledSwitchesEditorSheet: View {
    let remote: ProfileRemote
    let profileSet: TherapyProfileSet
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: [ScheduledProfileSwitch]
    @State private var editingID: String?

    init(remote: ProfileRemote, profileSet: TherapyProfileSet, onFinished: @escaping () -> Void) {
        self.remote = remote
        self.profileSet = profileSet
        self.onFinished = onFinished
        _draft = State(initialValue: profileSet.scheduledSwitches.entries)
    }

    private var list: ScheduledSwitchList { profileSet.scheduledSwitches }
    private var profileNames: [String] { profileSet.profiles.map(\.name) }
    private var problems: [String] {
        ScheduledSwitches.problems(draft, profileNames: profileNames, appName: remote.appName)
    }

    private var hasChanges: Bool { draft != list.entries }
    private var canAdd: Bool { draft.count < ScheduledProfileSwitch.maxCount && !profileNames.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Starts"),
                    footer: Text(draft.isEmpty
                        ? "No starts. \(remote.appName) keeps the active profile until someone switches."
                        : "Each profile stays active until the next start. Tap a start to change, pause or delete it.")
                ) {
                    ForEach(ScheduledSwitches.sortedForWeek(draft)) { entry in
                        Button {
                            editingID = entry.id
                        } label: {
                            HStack {
                                ScheduledSwitchRow(entry: entry, entries: draft)
                                Spacer()
                                if ScheduledSwitches.entryProblem(entry, in: draft, profileNames: profileNames, appName: remote.appName) != nil {
                                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let sorted = ScheduledSwitches.sortedForWeek(draft)
                        let ids = Set(offsets.map { sorted[$0].id })
                        draft.removeAll { ids.contains($0.id) }
                    }

                    Button {
                        let entry = ScheduledProfileSwitch(profile: profileSet.profiles.first?.name ?? TherapyProfile.defaultName, weekday: 2, time: 7 * 3600)
                        draft.append(entry)
                        editingID = entry.id
                    } label: {
                        Label("Add Start", systemImage: "plus.circle")
                    }
                    .disabled(!canAdd)
                }

                if let note = ScheduledSwitches.timeZoneNote(list.timeZone) {
                    Section { Text(note).foregroundColor(.secondary) }
                }

                if !problems.isEmpty {
                    Section(header: Text("Fix Before Sending")) {
                        ForEach(problems, id: \.self) { Text($0).foregroundColor(.red) }
                    }
                }

                Section {
                    ScheduledSwitchDosingNote()
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Scheduled Switches")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $editingID) { id in
                ScheduledSwitchEntryEditor(remote: remote, profileSet: profileSet, draft: $draft, id: id)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink("Review") {
                        ScheduledSwitchesReviewView(remote: remote, profileSet: profileSet, entries: draft, onFinished: onFinished)
                    }
                    .disabled(!hasChanges || !problems.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
    }
}

/// Edits one start: profile, weekday, time and pause.
struct ScheduledSwitchEntryEditor: View {
    let remote: ProfileRemote
    let profileSet: TherapyProfileSet
    @Binding var draft: [ScheduledProfileSwitch]
    let id: String

    @Environment(\.dismiss) private var dismiss

    private static let utc = TimeZone(identifier: "UTC")!

    private var index: Int? { draft.firstIndex { $0.id == id } }

    private var profileNames: [String] {
        var names = profileSet.profiles.map(\.name)
        if let index, !names.contains(draft[index].profile) { names.append(draft[index].profile) }
        return names
    }

    var body: some View {
        Form {
            if let index {
                let entry = draft[index]
                Section(footer: Text("\(entry.paused ? "Paused. When resumed, " : "")\(entry.profile) starts every \(ScheduledSwitches.weekdayName(entry.weekday)) at \(ScheduledSwitches.timeText(entry.time)) and stays active until the next scheduled start.")) {
                    Picker("Profile", selection: field(\.profile, of: entry)) {
                        ForEach(profileNames, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Day", selection: field(\.weekday, of: entry)) {
                        ForEach(ScheduledSwitches.weekdaysFromMonday, id: \.self) { weekday in
                            Text(ScheduledSwitches.weekdayName(weekday)).tag(weekday)
                        }
                    }
                    DatePicker("Time", selection: timeBinding(entry), displayedComponents: .hourAndMinute)
                        .environment(\.timeZone, Self.utc)
                }

                if let problem = ScheduledSwitches.entryProblem(entry, in: draft, profileNames: profileSet.profiles.map(\.name), appName: remote.appName) {
                    Section { Text(problem).foregroundColor(.red) }
                }

                Section(footer: Text("A paused start does not run until it is resumed. Nothing switches when it is resumed; the start runs again at its next time.")) {
                    Toggle("Paused", isOn: field(\.paused, of: entry))
                }

                Section {
                    Button("Delete Start", role: .destructive) {
                        draft.removeAll { $0.id == id }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Start")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A field of the start, found by its id on each access. Controls that are still on screen while the start is
    /// deleted read `entry`'s value and change nothing.
    private func field<Value>(_ keyPath: WritableKeyPath<ScheduledProfileSwitch, Value>, of entry: ScheduledProfileSwitch) -> Binding<Value> {
        Binding(
            get: { draft.first { $0.id == id }?[keyPath: keyPath] ?? entry[keyPath: keyPath] },
            set: { value in
                guard let index = draft.firstIndex(where: { $0.id == id }) else { return }
                draft[index][keyPath: keyPath] = value
            }
        )
    }

    /// The time of day as a date on 1 January 1970 in UTC, as the profile times are shown.
    private func timeBinding(_ entry: ScheduledProfileSwitch) -> Binding<Date> {
        let time = field(\.time, of: entry)
        return Binding(
            get: { Date(timeIntervalSince1970: TimeInterval(time.wrappedValue)) },
            set: { date in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = Self.utc
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                time.wrappedValue = (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60
            }
        )
    }
}

/// Shows what a scheduled switches save changes, and sends it after confirmation and device authentication.
struct ScheduledSwitchesReviewView: View {
    let remote: ProfileRemote
    let profileSet: TherapyProfileSet
    let entries: [ScheduledProfileSwitch]
    let onFinished: () -> Void

    @ObservedObject private var tracker = RemoteCommandTracker.shared
    @State private var alert: AlertType?
    @State private var showJSON = false
    @State private var pushSize: Int?
    @State private var pushSizeComputed = false
    @State private var checking = false

    private enum AlertType: Identifiable {
        case confirm
        case result(ProfileCommandResult)

        var id: String {
            switch self {
            case .confirm: return "confirm"
            case let .result(result): return "result-\(result.success)-\(result.message)"
            }
        }
    }

    private var list: ScheduledSwitchList { profileSet.scheduledSwitches }
    private var command: ProfileCommand { .saveScheduledSwitches(entries, baseFingerprint: list.fingerprint) }
    private var key: String { remote.key(for: command) }
    private var changes: [ScheduledSwitchChange] { ScheduledSwitchDiff.changes(from: list.entries, to: entries) }
    private var isSending: Bool { tracker.isBusy(key: key) }
    private var otherPending: Bool { !isSending && ProfileCommandFlow.isAnyPending(tracker, remote: remote) }

    private var problems: [String] {
        var problems = ScheduledSwitches.problems(entries, profileNames: profileSet.profiles.map(\.name), appName: remote.appName)
        if changes.isEmpty { problems.append("Nothing changed.") }
        return problems
    }

    /// Profiles that start in the new list and give more insulin than Default somewhere.
    private var increases: [(profile: TherapyProfile, increases: [ProfileInsulinIncrease])] {
        ScheduledSwitchDiff.moreInsulinProfiles(from: list.entries, to: entries, profiles: profileSet.profiles)
    }

    private var isTooLarge: Bool { (pushSize ?? 0) > ProfilePushSize.reviewLimit(for: remote) }

    private var canSend: Bool {
        pushSizeComputed && problems.isEmpty && !isTooLarge && !isSending && !otherPending && !checking
    }

    var body: some View {
        List {
            Section {
                Text("Replace the scheduled switches in \(remote.appName) with the list below. \(remote.appName) then switches profiles at these times by itself, without asking anyone, and each switch changes insulin dosing. Nothing switches when the list is saved.")
            }

            Section(header: Text("Changes")) {
                ForEach(changes) { change in
                    Text(change.text)
                        .foregroundColor(change.kind == .removed ? .secondary : .primary)
                }
            }

            ForEach(increases, id: \.profile.name) { item in
                Section(header: Text("When \(item.profile.name) starts")) {
                    MoreInsulinWarning(
                        increases: item.increases,
                        basalTotal: ProfileInsulinComparison.basalTotalIncrease(from: defaultValues, to: item.profile.values),
                        comparedWith: TherapyProfile.defaultName,
                        appliesNow: false
                    )
                }
            }

            Section(header: Text("The Week After Saving"), footer: Text(ScheduledSwitches.footerText(ScheduledSwitchList(entries: entries, fingerprint: "", isComplete: true, timeZone: list.timeZone), appName: remote.appName))) {
                if entries.isEmpty {
                    Text("No starts").foregroundColor(.secondary)
                }
                ForEach(ScheduledSwitches.sortedForWeek(entries)) { entry in
                    ScheduledSwitchRow(entry: entry, entries: entries)
                }
            }

            Section(header: Text("Sent to \(remote.appName)"), footer: sizeFooter) {
                LabeledValueRow(label: "Starts", value: "\(entries.count) of \(ScheduledProfileSwitch.maxCount)")
                LabeledValueRow(label: "Based on version", value: list.fingerprint)
                DisclosureGroup("Exact list", isExpanded: $showJSON) {
                    Text(Self.jsonText(entries))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if !problems.isEmpty {
                Section(header: Text("Can't Send")) {
                    ForEach(problems, id: \.self) { Text($0).foregroundColor(.red) }
                }
            }

            Section {
                ScheduledSwitchDosingNote()
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                alert = .confirm
            } label: {
                Group {
                    if isSending {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Waiting for \(remote.appName)...")
                        }
                    } else if checking {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("Checking the scheduled switches...")
                        }
                    } else if otherPending {
                        Text("Another Profile Command Is Pending")
                    } else {
                        Text("Send to \(remote.appName)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSend)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: entries) {
            pushSize = Self.computePushSize(entries, baseFingerprint: list.fingerprint, remote: remote)
            pushSizeComputed = true
        }
        .onProfileCommandResult(keys: [key], command: command) { _, result in
            alert = .result(result)
        }
        .alert(item: $alert) { type in
            switch type {
            case .confirm:
                return Alert(
                    title: Text("Save Scheduled Switches?"),
                    message: Text("\(remote.appName) replaces its scheduled switches with this list and switches profiles at these times without asking. Nothing switches right now."
                        + (increases.isEmpty ? "" : "\n\n" + increases.map { "\($0.profile.name) gives more insulin than Default." }.joined(separator: " "))),
                    primaryButton: .default(Text("Send"), action: send),
                    secondaryButton: .cancel()
                )
            case let .result(result):
                return Alert(
                    title: Text(ProfileCommandFlow.resultTitle(kind: .saveScheduledSwitches, success: result.success, message: result.message, remote: remote)),
                    message: Text(Self.resultMessage(result, remote: remote)),
                    dismissButton: .default(Text("OK")) {
                        if ProfileCommandFlow.leavesAfterResult(result, remote: remote) { onFinished() }
                    }
                )
            }
        }
    }

    private var defaultValues: TherapyProfileValues {
        profileSet.profiles.first(where: \.isDefault)?.values ?? TherapyProfileValues(units: TherapyProfileValues.mgdl, basal: [], carbRatio: [], sensitivity: [], target: [])
    }

    private var sizeFooter: Text {
        guard pushSizeComputed else { return Text("") }
        guard let pushSize else {
            return Text("The size of the command can not be computed until LoopFollow's own APNS credentials are set up in App Settings → APN.")
        }
        if isTooLarge {
            return Text(ScheduledSwitchesPushSize.tooLargeMessage(pushSize)).foregroundColor(.red)
        }
        return Text("Command size: about \(pushSize) of \(APNSDelivery.maxPayloadBytes) bytes.")
    }

    static func computePushSize(_ entries: [ScheduledProfileSwitch], baseFingerprint: String, remote: ProfileRemote) -> Int? {
        switch remote {
        case .loop:
            return LoopAPNSService().scheduledSwitchesSavePushSize(entries: entries, baseFingerprint: baseFingerprint)
        case .trio:
            return PushNotificationManager().scheduledSwitchesSavePushSize(entries: entries, baseFingerprint: baseFingerprint)
        }
    }

    static func resultMessage(_ result: ProfileCommandResult, remote: ProfileRemote) -> String {
        guard result.outdated else { return result.message }
        return result.message + "\n\nLoopFollow is loading the scheduled switches \(remote.appName) uploaded. Open them again to review the current list."
    }

    /// Why the reviewed list must not be sent now that `current` is the newest profile document, or nil.
    static func staleReason(baseFingerprint: String, entries: [ScheduledProfileSwitch], current: TherapyProfileSet?, remote: ProfileRemote) -> String? {
        guard let current else {
            return "LoopFollow could not load the scheduled switches from Nightscout to check that they are unchanged, so nothing was sent. Try again."
        }
        if current.scheduledSwitches.fingerprint != baseFingerprint || !current.scheduledSwitches.isComplete {
            return "The scheduled switches changed in \(remote.appName) while you were editing, so nothing was sent. Review them again."
        }
        let names = current.profiles.map(\.name)
        if let missing = entries.first(where: { entry in !names.contains { $0.caseInsensitiveCompare(entry.profile) == .orderedSame } }) {
            return "“\(missing.profile)” is no longer in the list uploaded by \(remote.appName), so nothing was sent. Review the scheduled switches again."
        }
        return nil
    }

    private func send() {
        checking = true
        let base = list.fingerprint
        ProfileCommandFlow.fetchProfileSet { current in
            checking = false
            if let reason = Self.staleReason(baseFingerprint: base, entries: entries, current: current, remote: remote) {
                if let current { Observable.shared.therapyProfiles.set(current) }
                alert = .result(ProfileCommandResult(success: false, message: reason, outdated: current != nil))
                return
            }
            ProfileCommandFlow.authenticateAndSend(command, to: remote, reason: "Confirm your identity to change the scheduled switches in \(remote.appName).") { message in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    alert = .result(ProfileCommandResult(success: false, message: message))
                }
            }
        }
    }

    static func jsonText(_ entries: [ScheduledProfileSwitch]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}
