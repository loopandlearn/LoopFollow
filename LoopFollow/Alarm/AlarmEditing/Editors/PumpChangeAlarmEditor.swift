// LoopFollow
// PumpChangeAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-17.

import SwiftUI

struct PumpChangeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when the pump / cannula is within the time "
                    + "window you choose below (relative to the 3-day change "
                    + "limit).",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Advance Notice",
                footer: "How many hours before the 3-day limit you’d like a reminder.",
                title: "Warning Time",
                range: 1 ... 24,
                step: 1,
                unitLabel: "Hours",
                value: Binding(
                    get: { alarm.threshold ?? 12 },
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
