// LoopFollow
// NotLoopingAlarmEditor.swift
// Created by Jonas Björkert on 2025-04-26.

import SwiftUI

struct NotLoopingAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when no successful loop has occurred for the time "
                    + "you set below.", alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "No Loop for…",
                footer: "Number of minutes since the last successful loop. "
                    + "When this time has elapsed, the alarm becomes eligible.",
                title: "Elapsed time",
                range: 16 ... 61,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: Binding(
                    get: { alarm.threshold ?? 31 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
