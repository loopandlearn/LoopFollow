// LoopFollow
// AlarmListView.swift

import SwiftUI

private enum SheetInfo: Identifiable {
    case picker
    case editor(id: UUID, isNew: Bool)

    var id: UUID {
        switch self {
        case .picker:
            return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        case let .editor(id, _):
            return id
        }
    }
}

struct AlarmListView: View {
    @ObservedObject private var store = Storage.shared.alarms
    @State private var sheetInfo: SheetInfo?
    @State private var deleteAfterDismiss: UUID?
    @State private var selectedAlarm: Alarm?

    // MARK: - Categorized Alarms

    private var snoozedAlarms: [Alarm] {
        store.value.filter { $0.snoozedUntil ?? .distantPast > Date() && $0.isEnabled }
            .sorted(by: Alarm.byPriorityThenSpec)
    }

    private var activeAlarms: [Alarm] {
        store.value.filter { $0.isEnabled && ($0.snoozedUntil ?? .distantPast <= Date()) }
            .sorted(by: Alarm.byPriorityThenSpec)
    }

    private var inactiveAlarms: [Alarm] {
        store.value.filter { !$0.isEnabled }
            .sorted(by: Alarm.byPriorityThenSpec)
    }

    // MARK: - Formatters

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    // MARK: - Body

    var body: some View {
        List {
            // --- SNOOZED ALARMS SECTION ---
            if !snoozedAlarms.isEmpty {
                Section(header: Text("Snoozed")) {
                    ForEach(snoozedAlarms) { alarm in
                        alarmRow(for: alarm)
                    }
                }
            }

            // --- ACTIVE ALARMS SECTION ---
            if !activeAlarms.isEmpty {
                Section(header: Text("Active")) {
                    ForEach(activeAlarms) { alarm in
                        alarmRow(for: alarm)
                    }
                }
            }

            // --- INACTIVE ALARMS SECTION ---
            if !inactiveAlarms.isEmpty {
                Section(header: Text("Inactive")) {
                    ForEach(inactiveAlarms) { alarm in
                        alarmRow(for: alarm)
                            .opacity(0.6)
                    }
                }
            }
        }
        .sheet(item: $sheetInfo, onDismiss: handleSheetDismiss) { info in
            sheetContent(for: info)
        }
        .navigationBarTitle("Alarms", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { sheetInfo = .picker } label: { Image(systemName: "plus") }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    // MARK: - Views

    private func alarmRow(for alarm: Alarm) -> some View {
        Button {
            selectedAlarm = alarm
            sheetInfo = .editor(id: alarm.id, isNew: false)
        } label: {
            HStack(spacing: 12) {
                Glyph(
                    symbol: alarm.type.icon,
                    tint: .primary
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(alarm.name)
                        .foregroundColor(.primary)

                    if let until = alarm.snoozedUntil, until > Date() {
                        HStack(spacing: 4) {
                            Image(systemName: "zzz")
                                .font(.caption2)
                            Text("Snoozed until \(until, formatter: timeFormatter)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                store.value.removeAll { $0.id == alarm.id }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - Sheet Management

    private func handleSheetDismiss() {
        if let id = deleteAfterDismiss,
           let idx = store.value.firstIndex(where: { $0.id == id })
        {
            store.value.remove(at: idx)
        }
        deleteAfterDismiss = nil
    }

    @ViewBuilder
    private func sheetContent(for info: SheetInfo) -> some View {
        switch info {
        case .picker:
            AddAlarmSheet { type in
                let new = Alarm(type: type)
                store.value.append(new)
                sheetInfo = .editor(id: new.id, isNew: true)
            }

        case let .editor(id, isNew):
            if let idx = store.value.firstIndex(where: { $0.id == id }) {
                AlarmEditor(
                    alarm: $store.value[idx],
                    isNew: isNew,
                    onDone: { sheetInfo = nil },
                    onCancel: {
                        if isNew { deleteAfterDismiss = id }
                        sheetInfo = nil
                    },
                    onDelete: {
                        deleteAfterDismiss = id
                        sheetInfo = nil
                    }
                )
            } else {
                Text("Alarm not found").padding()
            }
        }
    }
}
