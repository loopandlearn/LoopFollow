//
//  AlarmListView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

extension AlarmType {
    enum Group: String, CaseIterable {
        case glucose = "Glucose"
        case insulin = "Insulin / Food"
        case device  = "Device / System"
        case other   = "Other"
    }

    var group: Group {
        switch self {
        case .low, .high, .fastDrop, .fastRise, .missedReading:
            return .glucose
        case .iob, .bolus, .cob, .missedBolus, .recBolus:
            return .insulin
        case .battery, .batteryDrop, .pump, .pumpChange,
                .sensorChange, .notLooping, .buildExpire:
            return .device
        default:
            return .other
        }
    }

    var icon: String {
        switch self {
        case .low       : return "arrow.down"
        case .high      : return "arrow.up"
        case .fastDrop  : return "arrow.down.to.line"
        case .fastRise  : return "arrow.up.to.line"
        case .missedReading: return "wifi.slash"

        case .iob, .bolus: return "syringe"
        case .cob       : return "fork.knife"
        case .missedBolus: return "exclamationmark.arrow.triangle.2.circlepath"
        case .recBolus  : return "bolt.horizontal"

        case .battery   : return "battery.25"
        case .batteryDrop: return "battery.100.bolt"
        case .pump      : return "drop"
        case .pumpChange: return "arrow.triangle.2.circlepath"
        case .sensorChange: return "sensor.tag.radiowaves.forward"

        case .notLooping: return "circle.slash"
        case .buildExpire: return "calendar.badge.exclamationmark"

        case .overrideStart: return "play.circle"
        case .overrideEnd  : return "stop.circle"
        case .tempTargetStart: return "flag"
        case .tempTargetEnd  : return "flag.slash"
        }
    }

    var blurb: String {
        switch self {
        case .low:            return "Alerts when BG goes below a limit."
        case .high:           return "Alerts when BG rises above a limit."
        case .fastDrop:       return "Rapid downward BG trend."
        case .fastRise:       return "Rapid upward BG trend."
        case .missedReading:  return "No CGM data for X minutes."

        case .iob:            return "High insulin-on-board."
        case .bolus:          return "Large individual bolus."
        case .cob:            return "High carbs-on-board."
        case .missedBolus:    return "Carbs without bolus."
        case .recBolus:       return "Recommended bolus issued."

        case .battery:        return "Pump / phone battery low."
        case .batteryDrop:    return "Battery drops quickly."
        case .pump:           return "Reservoir level low."
        case .pumpChange:     return "Infusion-set change due."
        case .sensorChange:   return "Sensor change due."
        case .notLooping:     return "Loop hasn’t completed."
        case .buildExpire:    return "Follow-app build expiring."

        case .overrideStart:  return "Override just started."
        case .overrideEnd:    return "Override ended."
        case .tempTargetStart:return "Temp target started."
        case .tempTargetEnd:  return "Temp target ended."
        }
    }
}

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
                            Section(header:
                                        Text(group.rawValue)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            ) {
                                ForEach(AlarmType.allCases.filter { $0.group == group },
                                        id: \.self) { type in
                                    AlarmTile(type: type) {
                                        onSelect(type)
//                                        dismiss()
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
                    NavigationLink(alarm.name) {
                        AlarmEditor(alarm: binding(for: alarm))
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
}
