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

/// Snoozes until a time set with the Digital Crown (or − and +), in quarter hours: like the
/// phone's snooze date and time, so 07:00 set in the evening means tomorrow morning. Turning
/// on past midnight goes on into the next day, up to 24 hours ahead.
private struct SnoozeUntilTimeView: View {
    var onSnooze: (Date) -> Void
    /// The quarter hour the choices count from: now, rounded up.
    private let base: Date
    /// Minutes after `base`, in steps of 15.
    @State private var minutes: Double
    @FocusState private var focused: Bool

    init(current: Date?, onSnooze: @escaping (Date) -> Void) {
        self.onSnooze = onSnooze
        let base = Self.roundedUpToQuarter(Date())
        self.base = base
        // A running snooze's end, or an hour from now.
        let start = current.map { $0.timeIntervalSince(base) / 60 } ?? 60
        _minutes = State(initialValue: min(max((start / 15).rounded() * 15, Self.minimum), Self.maximum))
    }

    private static let minimum = 15.0
    private static let maximum = 24.0 * 60 - 15

    private var end: Date { base.addingTimeInterval(minutes * 60) }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                AmountField(
                    value: $minutes,
                    unit: "",
                    step: 15,
                    minimum: Self.minimum,
                    maximum: Self.maximum,
                    isHighlighted: focused,
                    format: { base.addingTimeInterval($0 * 60).formatted(date: .omitted, time: .shortened) }
                )
                .focused($focused)
                Text(Self.describe(end, now: Date()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Label("Turn to change", systemImage: CrownSymbol.increase)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Snooze") { onSnooze(end) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Until")
        .onAppear { focused = true }
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
