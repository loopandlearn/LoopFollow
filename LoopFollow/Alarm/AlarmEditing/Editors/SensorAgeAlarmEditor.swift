// LoopFollow
// SensorAgeAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-17.

import SwiftUI

struct SensorAgeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Warn me this many hours before the sensor’s 10-day change-over.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Advance warning",
                footer: "Number of hours before the 10-day mark that the alert " +
                    "will fire.",
                title: "Hours",
                range: 1 ... 24,
                step: 1,
                unitLabel: "hours",
                value: Binding(
                    get: { alarm.threshold ?? 12 },
                    set: { alarm.threshold = $0 }
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
