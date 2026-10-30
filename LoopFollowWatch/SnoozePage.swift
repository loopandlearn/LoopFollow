// LoopFollow
// SnoozePage.swift

import SwiftUI

/// Snoozes all alarms ahead of time, as the phone's Snoozer does with "Snooze all":
/// shows whether alarms are snoozed and for how long, and opens the snooze choices.
///
/// Modeled on Magnus Reintz's (t1dude) alarm snooze page for Trio's watch app
/// (nightscout/Trio: "Add alarm snooze page to watch app", "Address watch snooze
/// review feedback"): the bell in a circle with the minutes left, the snooze end
/// below it, and a sheet with End Snooze and the durations.
struct SnoozePage: View {
    let state: WatchState

    @EnvironmentObject private var session: WatchSession
    @State private var showingOptions = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            // Measured from now rather than the tick date, which can be stale (nightscout/Trio#1381).
            let now = max(context.date, Date())
            let until = state.snoozeAllUntil.flatMap { $0 > now ? $0 : nil }
            let minutesLeft = until.map { max(Int(ceil($0.timeIntervalSince(now) / 60)), 0) } ?? 0

            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Button {
                    showingOptions = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: until == nil ? "bell.fill" : "bell.slash.fill")
                            .font(.title2)
                        if until != nil {
                            Text(Self.remaining(minutesLeft))
                                .font(.headline).fontWeight(.bold).fontDesign(.rounded)
                        }
                    }
                    .foregroundStyle(until == nil ? Color.primary : Color.secondary)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color.primary.opacity(0.4), lineWidth: 2))
                }
                .buttonStyle(.plain)

                Text(until.map { "Snoozed until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Alarms active")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if state.source == .watch {
                    Text("Snoozing needs the iPhone")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Alarms"))
            .accessibilityValue(Text(until == nil ? "active" : "snoozed, \(minutesLeft) minutes remaining"))
            .accessibilityHint(Text("Opens snooze options"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { showingOptions = true }
        }
        .navigationTitle("Snooze")
        .sheet(isPresented: $showingOptions) {
            SnoozeOptionsView(snoozedUntil: state.snoozeAllUntil) {
                showingOptions = false
            }
            .environmentObject(session)
        }
    }

    /// "45 m" below an hour, "2 h 05" above.
    static func remaining(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) m" : String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

/// End Snooze while snoozed, then the snooze durations and a chosen end time. The phone applies the choice
/// and sends the new state back, so the page shows what the phone actually set.
private struct SnoozeOptionsView: View {
    let snoozedUntil: Date?
    var onDone: () -> Void

    @EnvironmentObject private var session: WatchSession
    @State private var isSending = false
    @State private var error: String?

    private static let durations: [(label: String, minutes: Int)] = [
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
        ("4 hours", 240),
    ]

    var body: some View {
        let isSnoozed = (snoozedUntil ?? .distantPast) > Date()
        NavigationStack {
            List {
                if isSnoozed {
                    Button {
                        send(until: nil)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "alarm.waves.left.and.right.fill")
                            Text("End Snooze")
                        }
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(Color.red.clipShape(RoundedRectangle(cornerRadius: 8)))

                    // Like the phone's "+ 30m".
                    Button("+ 30 minutes") {
                        send(until: (snoozedUntil ?? Date()).addingTimeInterval(30 * 60))
                    }
                }

                ForEach(Self.durations, id: \.minutes) { option in
                    Button(option.label) {
                        send(until: Date().addingTimeInterval(TimeInterval(option.minutes * 60)))
                    }
                }

                NavigationLink("Until a time…") {
                    SnoozeUntilTimeView(current: snoozedUntil) { end in
                        send(until: end)
                    }
                }
            }
            .disabled(isSending)
            .navigationTitle(isSending ? "Sending…" : "Snooze All")
        }
        .alert("Snooze failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func send(until: Date?) {
        Task {
            isSending = true
            let reply = await session.send(.snoozeAll(until: until))
            isSending = false
            if reply.success {
                onDone()
            } else {
                error = reply.message
            }
        }
    }
}

/// Snoozes until a time picked with the Digital Crown, like the phone's snooze date and time:
/// the next time the clock shows it, so 07:00 picked at 22:00 means tomorrow morning.
private struct SnoozeUntilTimeView: View {
    var onSnooze: (Date) -> Void
    @State private var time: Date

    init(current: Date?, onSnooze: @escaping (Date) -> Void) {
        self.onSnooze = onSnooze
        // A running snooze's end, or an hour from now rounded up to the quarter hour.
        let start = current.flatMap { $0 > Date() ? $0 : nil } ?? Self.roundedUpToQuarter(Date().addingTimeInterval(3600))
        _time = State(initialValue: start)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = max(context.date, Date())
            let end = Self.nextOccurrence(of: time, after: now)
            ScrollView {
                VStack(spacing: 6) {
                    DatePicker("Until", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text(Self.describe(end, now: now))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Snooze") { onSnooze(Self.nextOccurrence(of: time, after: Date())) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Until")
    }

    /// The first time after `now` the clock shows the picked hour and minute: today, or tomorrow
    /// once that has passed. Always within 24 hours, as the phone requires.
    static func nextOccurrence(of picked: Date, after now: Date) -> Date {
        let calendar = Calendar.current
        let clock = calendar.dateComponents([.hour, .minute], from: picked)
        return calendar.nextDate(after: now, matching: clock, matchingPolicy: .nextTime) ?? picked
    }

    /// "Today 23:30 · in 1 h 15" or "Tomorrow 07:00 · in 8 h 30".
    static func describe(_ end: Date, now: Date) -> String {
        let day = Calendar.current.isDate(end, inSameDayAs: now) ? "Today" : "Tomorrow"
        let minutes = max(Int(ceil(end.timeIntervalSince(now) / 60)), 0)
        return "\(day) \(end.formatted(date: .omitted, time: .shortened)) · in \(SnoozePage.remaining(minutes))"
    }

    static func roundedUpToQuarter(_ date: Date) -> Date {
        let quarter: TimeInterval = 15 * 60
        return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / quarter).rounded(.up) * quarter)
    }
}
