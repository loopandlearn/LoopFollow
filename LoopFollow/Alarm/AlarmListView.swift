//
//  AlarmListView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI

/// Displays all configured alarms and allows adding a new one by selecting its type.
struct AlarmListView: View {
    @ObservedObject private var store = Storage.shared.alarms
    @Environment(\.presentationMode) var presentationMode
    @State private var showingTypePicker = false
    @State private var editingAlarmID: UUID?

    var body: some View {
        NavigationView {
            List {
                // TODO: sort these in the alarm prio order, as they are evaluated
                ForEach(store.value) { alarm in
                    NavigationLink(alarm.name) {
                        AlarmEditor(alarm: binding(for: alarm))
                    }
                }
                .onDelete { idxs in
                    store.value.remove(atOffsets: idxs)
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingTypePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            // Step 1: pick a type for the new alarm
            // TODO: Sort these in the type order
            .actionSheet(isPresented: $showingTypePicker) {
                ActionSheet(
                    title: Text("Select Alarm Type"),
                    buttons: AlarmType.allCases.map { type in
                        .default(Text(type.rawValue)) {
                            let newAlarm = Alarm(type: type)
                            store.value.append(newAlarm)
                            editingAlarmID = newAlarm.id
                        }
                    } + [.cancel()]
                )
            }
            // Step 2: when an ID is set, present the editor
            .sheet(item: $editingAlarmID) { id in
                if let idx = store.value.firstIndex(where: { $0.id == id }) {
                    AlarmEditor(alarm: $store.value[idx])
                } else {
                    Text("Alarm not found")
                        .padding()
                }
            }
        }
    }

    /// Find and return a binding to the given alarm in the store
    private func binding(for alarm: Alarm) -> Binding<Alarm> {
        guard let idx = store.value.firstIndex(where: { $0.id == alarm.id }) else {
            fatalError("Alarm not found in store")
        }
        return $store.value[idx]
    }
}
