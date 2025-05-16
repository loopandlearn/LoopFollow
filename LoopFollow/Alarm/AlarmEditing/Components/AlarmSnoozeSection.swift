//
//  AlarmSnoozeSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-12.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AlarmSnoozeSection: View {
    @Binding var alarm: Alarm
    let range: ClosedRange<Int>
    let step: Int

    private var unitLabel: String { alarm.type.snoozeTimeUnit.label }

    private var defaultSnoozeBinding: Binding<Int> {
        Binding(
            get: { alarm.snoozeDuration },
            set: { alarm.snoozeDuration = $0 }
        )
    }

    private var isSnoozed: Binding<Bool> {
        Binding(
            get: {
                if let until = alarm.snoozedUntil, until > Date() { return true }
                return false
            },
            set: { on in
                if on {
                    if alarm.snoozedUntil == nil || alarm.snoozedUntil! < Date() {
                        let secs = alarm.type.snoozeTimeUnit.seconds
                        alarm.snoozedUntil = Date()
                            .addingTimeInterval(Double(alarm.snoozeDuration) * secs)
                    }
                } else {
                    alarm.snoozedUntil = nil
                }
            }
        )
    }

    var body: some View {
        Section(
            header: Text("SNOOZE"),
            footer: Text(
                "“Default Snooze” controls how long the alert stays quiet after "
                    + "you press Snooze. Toggle “Snoozed” to mute this alarm right now "
                    + "until the time below."
            )
        ) {
            Stepper(
                value: defaultSnoozeBinding,
                in: range,
                step: step
            ) {
                HStack {
                    Text("Default Snooze:")
                    Spacer()
                    Text("\(alarm.snoozeDuration) \(unitLabel)")
                        .foregroundColor(.secondary)
                }
            }

            Toggle("Snoozed", isOn: isSnoozed)

            if isSnoozed.wrappedValue, let until = alarm.snoozedUntil {
                DatePicker(
                    "Until",
                    selection: Binding(
                        get: { until },
                        set: { alarm.snoozedUntil = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
    }
}
