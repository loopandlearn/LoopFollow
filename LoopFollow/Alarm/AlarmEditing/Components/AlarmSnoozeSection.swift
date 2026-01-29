// LoopFollow
// AlarmSnoozeSection.swift

import SwiftUI

struct AlarmSnoozeSection: View {
    @Binding var alarm: Alarm

    private var unitLabel: String {
        alarm.type.snoozeTimeUnit.label
    }

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
                """
                “Default Snooze” controls the default value for how long the alert stays quiet after you press Snooze. \
                "A snooze duration of 0 means the alarm is acknowledged (silenced), and will alert again next time the condition applies, without time limitation. " \
                Toggle “Snoozed” to mute this alarm right now.
                """
            )
        ) {
            Stepper(
                value: defaultSnoozeBinding,
                in: alarm.type.snoozeRange,
                step: alarm.type.snoozeStep
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
