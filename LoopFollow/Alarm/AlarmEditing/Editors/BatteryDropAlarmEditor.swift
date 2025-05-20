// LoopFollow
// BatteryDropAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-20.

import SwiftUI

struct BatteryDropAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when the phone battery falls by a specified "
                    + "percentage within a set time window.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Drop Amount",
                footer: "Trigger when charge falls by at least this much.",
                title: "Δ %",
                range: 5 ... 100,
                step: 5,
                unitLabel: "%",
                value: Binding(
                    get: { alarm.delta ?? 10 },
                    set: { alarm.delta = $0 }
                )
            )

            AlarmStepperSection(
                header: "Time Window",
                footer: "How far back to look for that drop.",
                title: "Minutes",
                range: 5 ... 30,
                step: 5,
                value: Binding(
                    get: { Double(alarm.monitoringWindow ?? 15) },
                    set: { alarm.monitoringWindow = Int($0) }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm,
                               range: 1 ... 24,
                               step: 1)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
