// LoopFollow
// ProfileReviewView.swift

import SwiftUI

/// One row of a schedule comparison: the value in effect from `seconds` before and after the change.
struct ProfileDiffRow: Equatable, Identifiable {
    let seconds: Int
    let old: String
    let new: String

    var id: Int { seconds }
    var changed: Bool { old != new }
}

enum ProfileDiff {
    /// The value in effect at each time either schedule changes value, before and after.
    static func rows(old: [EditableSegment], new: [EditableSegment], text: (EditableSegment) -> String) -> [ProfileDiffRow] {
        let times = Set(old.map(\.seconds) + new.map(\.seconds)).sorted()
        func effective(_ segments: [EditableSegment], at seconds: Int) -> String {
            segments.last { $0.seconds <= seconds }.map(text) ?? "—"
        }
        return times.map { ProfileDiffRow(seconds: $0, old: effective(old, at: $0), new: effective(new, at: $0)) }
    }
}

/// Shows exactly what a profile save sends, compared with the profile it starts from, and sends it after
/// confirmation and device authentication.
struct ProfileReviewView: View {
    let remote: ProfileRemote
    let command: ProfileCommand
    /// The profile being changed, or the one a new profile is copied from.
    let baseline: TherapyProfile
    let isActive: Bool
    let limits: ProfileEditLimits?
    let onFinished: () -> Void

    @ObservedObject private var tracker = RemoteCommandTracker.shared
    @State private var alert: AlertType?
    @State private var showJSON = false
    /// The serialized push size, computed once per command; nil when it can not be computed.
    @State private var pushSize: Int?
    @State private var pushSizeComputed = false
    /// True while the newest profile document is loaded before a send.
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

    private var values: TherapyProfileValues {
        if case let .save(_, _, values) = command { return values }
        return baseline.values
    }

    private var original: TherapyProfile? {
        if case let .save(_, original, _) = command { return original }
        return nil
    }

    private var key: String { remote.key(for: command) }

    private var increases: [ProfileInsulinIncrease] {
        ProfileInsulinComparison.increases(from: baseline.values, to: values)
    }

    private var isSending: Bool { tracker.isBusy(key: key) }

    private var otherPending: Bool {
        !isSending && ProfileCommandFlow.isAnyPending(tracker, remote: remote)
    }

    private var problems: [String] {
        guard let limits else { return ["Profiles can not be changed without the limits from \(remote.appName)."] }
        return ProfileValidation.problems(for: command, limits: limits)
    }

    private static func computePushSize(_ command: ProfileCommand, remote: ProfileRemote) -> Int? {
        guard case let .save(name, original, values) = command else { return nil }
        switch remote {
        case .loop:
            return LoopAPNSService().profileSavePushSize(name: name, originalName: original?.name, baseFingerprint: original?.fingerprint, values: values)
        case .trio:
            return PushNotificationManager().profileSavePushSize(name: name, originalName: original?.name, baseFingerprint: original?.fingerprint, values: values)
        }
    }

    private var isTooLarge: Bool {
        (pushSize ?? 0) > ProfilePushSize.reviewLimit(for: remote)
    }

    private var canSend: Bool {
        pushSizeComputed && problems.isEmpty && !isTooLarge && !isSending && !otherPending && !checking
    }

    var body: some View {
        List {
            Section {
                Text(summary)
                if appliesNow {
                    ActiveProfileWarning(remote: remote)
                }
                if !increases.isEmpty {
                    MoreInsulinWarning(
                        increases: increases,
                        basalTotal: ProfileInsulinComparison.basalTotalIncrease(from: baseline.values, to: values),
                        comparedWith: original?.name ?? baseline.name,
                        appliesNow: appliesNow
                    )
                }
            }

            ForEach(ProfileScheduleKind.allCases) { kind in
                diffSection(kind)
            }

            Section(header: Text("Sent to \(remote.appName)"), footer: sizeFooter(pushSize)) {
                LabeledValueRow(label: "Name", value: command.targetName)
                if let original {
                    if original.name != command.targetName {
                        LabeledValueRow(label: "Renames", value: original.name)
                    }
                    LabeledValueRow(label: "Based on version", value: original.fingerprint)
                }
                LabeledValueRow(label: "Units", value: values.units)
                DisclosureGroup("Exact values", isExpanded: $showJSON) {
                    Text(Self.jsonText(values))
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
                ProfileDosingNote()
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
                            Text("Checking the profile...")
                        }
                    } else if otherPending {
                        Text("Another Profile Command Is Pending")
                    } else {
                        Text(appliesNow ? "Send and Apply Now" : "Send to \(remote.appName)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(appliesNow ? .red : .accentColor)
            .controlSize(.large)
            .disabled(!canSend)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: command) {
            pushSize = Self.computePushSize(command, remote: remote)
            pushSizeComputed = true
        }
        .onProfileCommandResult(keys: [key], command: command) { _, result in
            alert = .result(result)
        }
        .alert(item: $alert) { type in
            switch type {
            case .confirm:
                return Alert(
                    title: Text(confirmTitle),
                    message: Text(confirmMessage),
                    primaryButton: appliesNow ? .destructive(Text("Send"), action: send) : .default(Text("Send"), action: send),
                    secondaryButton: .cancel()
                )
            case let .result(result):
                return Alert(
                    title: Text(ProfileCommandFlow.resultTitle(kind: .save, success: result.success, message: result.message, remote: remote)),
                    message: Text(ProfileCommandFlow.resultMessage(result, remote: remote)),
                    dismissButton: .default(Text("OK")) {
                        if ProfileCommandFlow.leavesAfterResult(result, remote: remote) { onFinished() }
                    }
                )
            }
        }
    }

    private var summary: String {
        if let original {
            if original.name != command.targetName {
                return "Rename “\(original.name)” to “\(command.targetName)” in \(remote.appName)."
            }
            return "Save these changes to “\(original.name)” in \(remote.appName). Changed values are marked."
        }
        return "Create “\(command.targetName)” in \(remote.appName), starting from “\(baseline.name)”. Values that differ from “\(baseline.name)” are marked."
    }

    private var isRename: Bool {
        command.isRename
    }

    /// True when the command changes the values the phone doses with as soon as it arrives. A rename keeps the values.
    private var appliesNow: Bool {
        isActive && !isRename
    }

    private var confirmTitle: String {
        if isRename { return "Rename \(original?.name ?? "")?" }
        if isActive { return "Change the Active Profile?" }
        return original == nil ? "Create \(command.targetName)?" : "Save \(command.targetName)?"
    }

    private var confirmMessage: String {
        if isRename {
            return "Only the name changes. The values stay the same, so dosing does not change."
        }
        if isActive {
            return "\(remote.appName) starts dosing with these values as soon as it gets the command, and sends the new basal rates to the pump."
                + MoreInsulinWarning.sentence(increases, comparedWith: original?.name ?? baseline.name)
        }
        return "\(remote.appName) saves the profile. Dosing does not change unless this profile is the active one in \(remote.appName) when the command arrives."
            + MoreInsulinWarning.sentence(increases, comparedWith: original?.name ?? baseline.name)
    }

    private func diffSection(_ kind: ProfileScheduleKind) -> some View {
        let unitText = kind.unitText(glucoseUnits: values.units)
        let singleTarget = remote.hasSingleTarget
        let old = ProfileDraft(baseline.values, singleTarget: singleTarget)[kind]
        let new = ProfileDraft(values, singleTarget: singleTarget)[kind]
        let rows = ProfileDiff.rows(old: old, new: new) { ProfileValueFormat.segmentText($0, kind: kind, limits: limits, glucoseUnits: values.units, singleTarget: singleTarget) }
        let changed = rows.contains(where: \.changed) || old.map(\.seconds) != new.map(\.seconds)
        let moreInsulin = increases.first { $0.kind == kind }?.periods ?? []
        let footer = changed
            ? "Before → after, in \(unitText)." + (moreInsulin.isEmpty ? "" : " Red values give more insulin.")
            : "Unchanged, in \(unitText)."
        return Section(header: Text(singleTarget && kind.isRange ? "Glucose Target" : kind.title), footer: Text(footer)) {
            ForEach(rows) { row in
                ProfileRowLayout {
                    Text(ProfileValueFormat.timeText(row.seconds))
                } value: {
                    if row.changed {
                        HStack {
                            Text(row.old)
                                .foregroundColor(.secondary)
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(row.new)
                                .bold()
                                .foregroundColor(moreInsulin.contains { $0.lowerBound <= row.seconds && row.seconds < $0.upperBound } ? .red : .orange)
                        }
                    } else {
                        Text(row.new).foregroundColor(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.changed
                    ? "\(ProfileValueFormat.timeText(row.seconds)), changed from \(row.old) to \(row.new)"
                    : "\(ProfileValueFormat.timeText(row.seconds)), \(row.new)")
            }
        }
    }

    private func sizeFooter(_ size: Int?) -> Text {
        guard pushSizeComputed else { return Text("") }
        guard let size else {
            return Text("The size of the command can not be computed until LoopFollow's own APNS credentials are set up in App Settings → APN.")
        }
        if size > ProfilePushSize.reviewLimit(for: remote) {
            return Text(ProfilePushSize.tooLargeMessage(size)).foregroundColor(.red)
        }
        return Text("Command size: about \(size) of \(APNSDelivery.maxPayloadBytes) bytes.")
    }

    /// Checks against the newest profile document that the profile is unchanged and has the active state the review
    /// showed, then sends after device authentication.
    private func send() {
        guard let original else {
            authenticateAndSend()
            return
        }
        checking = true
        ProfileCommandFlow.fetchProfileSet { current in
            checking = false
            guard let reason = ProfileCommandFlow.saveStaleReason(original: original, reviewedActive: isActive, current: current, remote: remote) else {
                authenticateAndSend()
                return
            }
            if let current { Observable.shared.therapyProfiles.set(current) }
            alert = .result(ProfileCommandResult(success: false, message: reason, outdated: current != nil))
        }
    }

    private func authenticateAndSend() {
        ProfileCommandFlow.authenticateAndSend(command, to: remote, reason: "Confirm your identity to change \(command.targetName) in \(remote.appName).") { message in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                alert = .result(ProfileCommandResult(success: false, message: message))
            }
        }
    }

    static func jsonText(_ values: TherapyProfileValues) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(values), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}
