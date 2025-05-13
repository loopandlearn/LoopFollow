//
//  AlarmListView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AddAlarmSheet: View {
    let onSelect: (AlarmType) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AlarmType.Group.allCases, id: \.self) { group in
                        if AlarmType.allCases.contains(where: { $0.group == group }) {
                            Section(header: Text(group.rawValue)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            ) {
                                ForEach(AlarmType.allCases.filter { $0.group == group }, id: \.self) { type in
                                    AlarmTile(type: type) {
                                        onSelect(type)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Add Alarm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct AlarmTile: View {
    let type: AlarmType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(type.rawValue)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(type.blurb)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private enum SheetInfo: Identifiable {
    case picker
    case editor(id: UUID, isNew: Bool)

    var id: UUID {
        switch self {
        case .picker:
            return UUID(uuidString:"00000000-0000-0000-0000-000000000000")!
        case .editor(let id, _):
            return id
        }
    }
}

struct AlarmListView: View {
    @ObservedObject private var store = Storage.shared.alarms
    @Environment(\.dismiss) private var dismiss

    @State private var sheetInfo: SheetInfo?
    @State private var deleteAfterDismiss: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.value) { alarm in
                    NavigationLink {
                        AlarmEditor(alarm: binding(for: alarm))
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Image(systemName: alarm.type.icon)
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(alarm.isEnabled ? Color.accentColor : Color.secondary)
                                    .opacity(iconOpacity(for: alarm))

                                if let until = alarm.snoozedUntil, until > Date() {
                                    Image(systemName: "zzz")
                                        .font(.title3)
                                        .foregroundStyle(Color.secondary)
                                        .shadow(color: .black.opacity(1), radius: 2, x: 0, y: 0)
                                        .blendMode(.screen)
                                        .offset(x: 6, y: 6)
                                }
                            }
                            .frame(width: 26, height: 26)

                            Text(alarm.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .onDelete { store.value.remove(atOffsets: $0) }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { sheetInfo = .picker } label: { Image(systemName:"plus") }
                }
            }
            .sheet(item: $sheetInfo,
                   onDismiss: handleSheetDismiss) { info in
                sheetContent(for: info)
            }
        }
    }

    private func handleSheetDismiss() {
        if let id = deleteAfterDismiss,
           let idx = store.value.firstIndex(where: { $0.id == id }) {
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

        case .editor(let id, let isNew):
            if let idx = store.value.firstIndex(where: { $0.id == id }) {
                AlarmEditor(
                    alarm: $store.value[idx],
                    isNew:  isNew,
                    onDone: { sheetInfo = nil },
                    onCancel: {
                        deleteAfterDismiss = id
                        sheetInfo = nil
                    }
                )
            } else {
                Text("Alarm not found").padding()
            }
        }
    }

    private func binding(for alarm: Alarm) -> Binding<Alarm> {
        guard let idx = store.value.firstIndex(where: { $0.id == alarm.id }) else {
            fatalError("Alarm not found")
        }
        return $store.value[idx]
    }

    private func iconOpacity(for alarm: Alarm) -> Double {
        if !alarm.isEnabled { return 0.35 }
        if let until = alarm.snoozedUntil, until > Date() { return 0.55 }
        return 1.0
    }
}
