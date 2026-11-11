// LoopFollow
// ScheduledSwitches.swift

import Foundation

/// The scheduled switches in the latest profile document of Loop or Trio.
struct ScheduledSwitchList: Equatable {
    /// The entries, with Trio's `default` named Default as in the profile list.
    let entries: [ScheduledProfileSwitch]
    /// Fingerprint of the list as uploaded. A replace command sends it so the phone only replaces this list.
    let fingerprint: String
    /// False when an entry could not be read or the list does not match the fingerprint the phone uploaded, so the
    /// list can not be replaced faithfully.
    let isComplete: Bool
    /// The time zone of the therapy schedules, in which the start times apply.
    let timeZone: TimeZone

    static let empty = ScheduledSwitchList(entries: [], fingerprint: ScheduledProfileSwitch.fingerprint([]), isComplete: true, timeZone: .current)

    init(entries: [ScheduledProfileSwitch], fingerprint: String, isComplete: Bool, timeZone: TimeZone) {
        self.entries = entries
        self.fingerprint = fingerprint
        self.isComplete = isComplete
        self.timeZone = timeZone
    }

    init(_ profile: NSProfile) {
        let readable = profile.scheduledSwitches.map { $0.value != nil } ?? true
        let decoded = profile.scheduledSwitches?.value ?? []
        let raw = decoded.compactMap(\.value)
        let fingerprint = ScheduledProfileSwitch.fingerprint(raw)
        let uploaded = profile.scheduledSwitchesFingerprint
        self.init(
            entries: raw.map { entry in
                var entry = entry
                if TherapyProfile.isDefaultName(entry.profile) { entry.profile = TherapyProfile.defaultName }
                return entry
            },
            fingerprint: fingerprint,
            isComplete: readable && raw.count == decoded.count && (uploaded == nil || uploaded == fingerprint),
            timeZone: profile.store[profile.defaultProfile].map { ScheduledSwitches.timeZone(identifier: $0.timezone) } ?? .current
        )
    }

    var pausedCount: Int { entries.filter(\.paused).count }
}

/// Week order, occurrences, validation and wording for scheduled switches.
enum ScheduledSwitches {
    static let secondsPerDay = 86400

    /// A Nightscout `timezone` value, also in the `ETC/GMT+1` spelling some uploaders use.
    static func timeZone(identifier: String) -> TimeZone {
        if let zone = TimeZone(identifier: identifier) ?? TimeZone(identifier: identifier.replacingOccurrences(of: "ETC/", with: "Etc/")) {
            return zone
        }
        let parts = identifier.uppercased().components(separatedBy: "GMT")
        if parts.count > 1, let hours = Int(parts[1]), let zone = TimeZone(secondsFromGMT: -hours * 3600) {
            return zone
        }
        return .current
    }

    /// Monday first, Sunday last.
    static func weekPosition(_ weekday: Int) -> Int {
        (weekday + 5) % 7
    }

    /// Calendar weekdays (Sunday = 1) from Monday.
    static let weekdaysFromMonday = [2, 3, 4, 5, 6, 7, 1]

    /// Seconds from Monday 00:00.
    static func weekSeconds(_ entry: ScheduledProfileSwitch) -> Int {
        weekPosition(entry.weekday) * secondsPerDay + entry.time
    }

    /// The entries as a week from Monday.
    static func sortedForWeek(_ entries: [ScheduledProfileSwitch]) -> [ScheduledProfileSwitch] {
        entries.sorted { lhs, rhs in
            if weekSeconds(lhs) != weekSeconds(rhs) { return weekSeconds(lhs) < weekSeconds(rhs) }
            return lhs.profile.localizedStandardCompare(rhs.profile) == .orderedAscending
        }
    }

    /// The unpaused start that ends the span of `entry`: the next unpaused start after it in the week, counting
    /// round to the following week. Nil when `entry` is paused or no other unpaused start exists.
    static func following(_ entry: ScheduledProfileSwitch, in entries: [ScheduledProfileSwitch]) -> ScheduledProfileSwitch? {
        guard !entry.paused else { return nil }
        let week = 7 * secondsPerDay
        let start = weekSeconds(entry)
        return entries
            .filter { !$0.paused && $0.id != entry.id }
            .min { lhs, rhs in
                let left = (weekSeconds(lhs) - start + week) % week
                let right = (weekSeconds(rhs) - start + week) % week
                return (left == 0 ? week : left) < (right == 0 ? week : right)
            }
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The next start of `entry` after `date`, in `timeZone`.
    static func nextOccurrence(of entry: ScheduledProfileSwitch, after date: Date, timeZone: TimeZone) -> Date? {
        let components = DateComponents(hour: entry.time / 3600, minute: entry.time % 3600 / 60, weekday: entry.weekday)
        return calendar(timeZone).nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    /// The next unpaused start after `date`.
    static func next(in entries: [ScheduledProfileSwitch], after date: Date, timeZone: TimeZone) -> (entry: ScheduledProfileSwitch, date: Date)? {
        entries
            .filter { !$0.paused }
            .compactMap { entry in nextOccurrence(of: entry, after: date, timeZone: timeZone).map { (entry, $0) } }
            .min { $0.1 < $1.1 }
    }

    /// The list with the start `id` paused, or resumed when it is paused. Nothing else changes.
    static func togglingPause(of id: String, in entries: [ScheduledProfileSwitch]) -> [ScheduledProfileSwitch] {
        entries.map { entry in
            guard entry.id == id else { return entry }
            var changed = entry
            changed.paused.toggle()
            return changed
        }
    }

    // MARK: Validation

    /// The phone's rules for a list, as sentences; empty when the list can be sent.
    static func problems(_ entries: [ScheduledProfileSwitch], profileNames: [String], appName: String) -> [String] {
        var problems: [String] = []
        if entries.count > ScheduledProfileSwitch.maxCount {
            problems.append("There can be at most \(ScheduledProfileSwitch.maxCount) scheduled switches. Delete one before adding another.")
        }
        for entry in sortedForWeek(entries) {
            if let problem = entryProblem(entry, in: entries, profileNames: profileNames, appName: appName), !problems.contains(problem) {
                problems.append(problem)
            }
        }
        return problems
    }

    /// Why one entry can not be sent, or nil.
    static func entryProblem(_ entry: ScheduledProfileSwitch, in entries: [ScheduledProfileSwitch], profileNames: [String], appName: String) -> String? {
        if !profileNames.contains(where: { $0.caseInsensitiveCompare(entry.profile) == .orderedSame }) {
            return "“\(entry.profile)” is not a profile in \(appName). Choose another profile or delete this start."
        }
        if !(1 ... 7).contains(entry.weekday) {
            return "A start has no valid weekday."
        }
        if entry.time < 0 || entry.time >= secondsPerDay || entry.time % 60 != 0 {
            return "A start time must be a whole minute of the day."
        }
        if let other = entries.first(where: { $0.id != entry.id && $0.weekday == entry.weekday && $0.time == entry.time }) {
            if other.profile.caseInsensitiveCompare(entry.profile) == .orderedSame {
                return "\(entry.profile) starts twice on \(slotText(entry)). Delete one of them."
            }
            let first = [entry, other].min { $0.profile.localizedStandardCompare($1.profile) == .orderedAscending }!
            let second = first.id == entry.id ? other : entry
            return "\(first.profile) and \(second.profile) both start on \(slotText(entry)). Only one profile can start at a time."
        }
        return nil
    }

    // MARK: Wording

    static func weekdayName(_ weekday: Int, short: Bool = false) -> String {
        let symbols = short ? Calendar.current.shortWeekdaySymbols : Calendar.current.weekdaySymbols
        guard (1 ... 7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }

    /// The start time, as the profile values show their times.
    static func timeText(_ seconds: Int) -> String {
        ProfileValueFormat.timeText(seconds)
    }

    /// "Saturday 13:00".
    static func slotText(_ entry: ScheduledProfileSwitch, short: Bool = false) -> String {
        "\(weekdayName(entry.weekday, short: short)) \(timeText(entry.time))"
    }

    /// "Weekend starts Saturday 13:00".
    static func startText(_ entry: ScheduledProfileSwitch, short: Bool = false) -> String {
        "\(entry.profile) starts \(slotText(entry, short: short))"
    }

    /// The second line of a row: "Paused", or how long the profile stays active.
    static func spanText(_ entry: ScheduledProfileSwitch, in entries: [ScheduledProfileSwitch]) -> String {
        if entry.paused { return "Paused" }
        if let following = following(entry, in: entries) {
            return "until \(slotText(following, short: true))"
        }
        return "until it starts again next week"
    }

    /// The footer of the list: what runs next, and which starts are paused.
    static func footerText(_ list: ScheduledSwitchList, appName: String, now: Date = Date()) -> String {
        guard !list.entries.isEmpty else {
            return "No scheduled switches. \(appName) keeps the active profile until someone switches."
        }
        var sentences: [String] = []
        if let next = next(in: list.entries, after: now, timeZone: list.timeZone) {
            sentences.append("Next: \(startText(next.entry)).")
        }
        let paused = list.pausedCount
        if paused == list.entries.count {
            sentences.append(paused == 1 ? "The start is paused." : "All starts are paused.")
        } else if paused > 0 {
            sentences.append(paused == 1 ? "1 start paused." : "\(paused) starts paused.")
        }
        let unpaused = list.entries.filter { !$0.paused }
        if unpaused.count == 1, let only = unpaused.first {
            sentences.append("\(only.profile) starts again every \(slotText(only)) after a manual switch.")
        }
        sentences.append("A profile stays active until the next start, also after a manual switch. Paused starts do not run, and resuming one switches nothing until its next time.")
        return sentences.joined(separator: " ")
    }

    /// The sentence for a profile switch: how long the switched-to profile stays active.
    static func holdText(_ list: ScheduledSwitchList, now: Date = Date()) -> String? {
        guard let next = next(in: list.entries, after: now, timeZone: list.timeZone) else { return nil }
        return "It stays active until \(startText(next.entry))."
    }

    /// The sentences for deleting a profile: the scheduled switches that go with it, and what that does to the week.
    static func deletionText(_ list: ScheduledSwitchList, profileName: String) -> String? {
        let count = list.entries.filter { $0.profile.caseInsensitiveCompare(profileName) == .orderedSame }.count
        guard count > 0 else { return nil }
        let removed = count == 1
            ? "\(profileName) is used by 1 scheduled switch, which will be removed."
            : "\(profileName) is used by \(count) scheduled switches, which will be removed."
        return removed + " At those times the profile active before stays active until the next scheduled start."
    }

    /// A note when the profile's time zone is not this phone's.
    static func timeZoneNote(_ timeZone: TimeZone, now: Date = Date()) -> String? {
        guard timeZone.secondsFromGMT(for: now) != TimeZone.current.secondsFromGMT(for: now) else { return nil }
        let name = timeZone.localizedName(for: .generic, locale: .current) ?? timeZone.identifier
        return "Times are in the profile's time zone (\(name)), not this phone's."
    }
}

/// One difference between the list before and after an edit.
struct ScheduledSwitchChange: Identifiable, Equatable {
    enum Kind: Equatable {
        case added
        case removed
        case changed
        case paused
        case resumed
    }

    let kind: Kind
    let old: ScheduledProfileSwitch?
    let new: ScheduledProfileSwitch?

    var id: String { (new ?? old)?.id ?? "" }

    var text: String {
        switch kind {
        case .added:
            return "Added: \(new.map { ScheduledSwitches.startText($0) } ?? "")" + (new?.paused == true ? " (paused)" : "")
        case .removed:
            return "Removed: \(old.map { ScheduledSwitches.startText($0) } ?? "")"
        case .changed:
            let paused = new?.paused == true ? " (paused)" : ""
            return "Changed: \(old.map { ScheduledSwitches.startText($0) } ?? "") → \(new.map { ScheduledSwitches.startText($0) } ?? "")\(paused)"
        case .paused:
            return "Paused: \(new.map { ScheduledSwitches.startText($0) } ?? "")"
        case .resumed:
            return "Resumed: \(new.map { ScheduledSwitches.startText($0) } ?? "")"
        }
    }
}

enum ScheduledSwitchDiff {
    /// Entries are matched by `id`. A change of only `paused` is a pause or resume; any other change, with or
    /// without `paused`, is a change.
    static func changes(from old: [ScheduledProfileSwitch], to new: [ScheduledProfileSwitch]) -> [ScheduledSwitchChange] {
        var changes: [ScheduledSwitchChange] = []
        let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(new.map(\.id))
        for entry in ScheduledSwitches.sortedForWeek(new) {
            guard let before = oldByID[entry.id] else {
                changes.append(ScheduledSwitchChange(kind: .added, old: nil, new: entry))
                continue
            }
            let sameStart = before.profile == entry.profile && before.weekday == entry.weekday && before.time == entry.time
            if !sameStart {
                changes.append(ScheduledSwitchChange(kind: .changed, old: before, new: entry))
            } else if before.paused != entry.paused {
                changes.append(ScheduledSwitchChange(kind: entry.paused ? .paused : .resumed, old: before, new: entry))
            }
        }
        for entry in ScheduledSwitches.sortedForWeek(old) where !newIDs.contains(entry.id) {
            changes.append(ScheduledSwitchChange(kind: .removed, old: entry, new: nil))
        }
        return changes
    }

    /// The target profiles that start in the new list where they did not before, unpaused: added, changed or
    /// resumed entries. Each name once, in week order.
    static func newlyStartingProfiles(from old: [ScheduledProfileSwitch], to new: [ScheduledProfileSwitch]) -> [String] {
        var names: [String] = []
        for change in changes(from: old, to: new) {
            guard let entry = change.new, !entry.paused, change.kind != .removed, change.kind != .paused else { continue }
            if !names.contains(entry.profile) { names.append(entry.profile) }
        }
        return names
    }

    /// The profiles that start in the new list where they did not before and give more insulin than Default
    /// somewhere, compared in mg/dL whatever units each profile has.
    static func moreInsulinProfiles(
        from old: [ScheduledProfileSwitch],
        to new: [ScheduledProfileSwitch],
        profiles: [TherapyProfile]
    ) -> [(profile: TherapyProfile, increases: [ProfileInsulinIncrease])] {
        guard let base = profiles.first(where: \.isDefault) else { return [] }
        return newlyStartingProfiles(from: old, to: new).compactMap { name in
            guard let profile = profiles.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }), !profile.isDefault else {
                return nil
            }
            let increases = ProfileInsulinComparison.increases(from: base.values, to: profile.values)
            return increases.isEmpty ? nil : (profile, increases)
        }
    }
}
