// LoopFollow
// AlarmSettingsView.swift

import SwiftUI

struct AlarmSettingsView: View {
    @ObservedObject private var cfgStore = Storage.shared.alarmConfiguration

    /// Helper to bind an optional Date? into a non‑optional Date for DatePicker
    private func optDateBinding(_ b: Binding<Date?>) -> Binding<Date> {
        Binding(
            get: { b.wrappedValue ?? Date() },
            set: { b.wrappedValue = $0 }
        )
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = cfgStore.value.dayStart.hour
                c.minute = cfgStore.value.dayStart.minute
                return Calendar.current.date(from: c)!
            },
            set: { d in
                let hc = Calendar.current.dateComponents([.hour, .minute], from: d)
                cfgStore.value.dayStart = TimeOfDay(hour: hc.hour!, minute: hc.minute!)
            }
        )
    }

    private var nightBinding: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = cfgStore.value.nightStart.hour
                c.minute = cfgStore.value.nightStart.minute
                return Calendar.current.date(from: c)!
            },
            set: { d in
                let hc = Calendar.current.dateComponents([.hour, .minute], from: d)
                cfgStore.value.nightStart = TimeOfDay(hour: hc.hour!, minute: hc.minute!)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("All Alerts Snoozed", isOn: Binding(
                    get: {
                        if let until = cfgStore.value.snoozeUntil { return until > Date() }
                        return false
                    },
                    set: { on in
                        if on {
                            let target = cfgStore.value.snoozeUntil ?? Date()
                            if target <= Date() {
                                cfgStore.value.snoozeUntil = Date().addingTimeInterval(3600)
                            }
                        } else {
                            cfgStore.value.snoozeUntil = nil
                        }
                    }
                ))

                if let until = cfgStore.value.snoozeUntil, until > Date() {
                    DatePicker(
                        "Until",
                        selection: optDateBinding(
                            Binding(
                                get: { cfgStore.value.snoozeUntil },
                                set: { cfgStore.value.snoozeUntil = $0 }
                            )
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }

                Toggle("All Sounds Muted", isOn: Binding(
                    get: {
                        if let until = cfgStore.value.muteUntil { return until > Date() }
                        return false
                    },
                    set: { on in
                        if on {
                            let target = cfgStore.value.muteUntil ?? Date()
                            if target <= Date() {
                                cfgStore.value.muteUntil = Date().addingTimeInterval(3600)
                            }
                        } else {
                            cfgStore.value.muteUntil = nil
                        }
                    }
                ))

                if let until = cfgStore.value.muteUntil, until > Date() {
                    DatePicker(
                        "Until",
                        selection: optDateBinding(
                            Binding(
                                get: { cfgStore.value.muteUntil },
                                set: { cfgStore.value.muteUntil = $0 }
                            )
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
            } header: {
                Label("Snooze & Mute Options", systemImage: "moon.zzz")
            } footer: {
                Text("""
                "Snooze All" disables every alarm. \
                "Mute All" silences phone sounds but still vibrates \
                and shows iOS notifications.
                """)
            }

            Section {
                DatePicker(
                    "Day starts",
                    selection: dayBinding,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)

                DatePicker(
                    "Night starts",
                    selection: nightBinding,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
            } header: {
                Label("Day / Night Schedule", systemImage: "sun.and.horizon")
            } footer: {
                Text("Pick when your day period begins and when your night period begins. " +
                    "Any time from your Day-starts time up until your Night-starts time will count as day; " +
                    "from Night-starts until the next Day-starts will count as night.")
            }

            Section {
                Toggle(
                    "Override System Volume",
                    isOn: $cfgStore.value.binding(\.overrideSystemOutputVolume)
                )

                if cfgStore.value.overrideSystemOutputVolume {
                    Stepper(
                        "Volume Level: \(Int(cfgStore.value.forcedOutputVolume * 100))%",
                        value: Binding(
                            get: { Double(cfgStore.value.forcedOutputVolume) },
                            set: { cfgStore.value.forcedOutputVolume = Float($0) }
                        ),
                        in: 0 ... 1,
                        step: 0.05
                    )
                }

                Toggle(
                    "Audio During Calls",
                    isOn: $cfgStore.value.binding(\.audioDuringCalls)
                )

                Toggle(
                    "Ignore Zero BG",
                    isOn: $cfgStore.value.binding(\.ignoreZeroBG)
                )

                Toggle(
                    "Auto‑Snooze CGM Start",
                    isOn: $cfgStore.value.binding(\.autoSnoozeCGMStart)
                )

                Toggle(
                    "Volume Buttons Snooze Alarms",
                    isOn: $cfgStore.value.binding(\.enableVolumeButtonSnooze)
                )
            } header: {
                Label("Alarm Settings", systemImage: "bell.badge")
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Alarm Settings", displayMode: .inline)
    }
}
