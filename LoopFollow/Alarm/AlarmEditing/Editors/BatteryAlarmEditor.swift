// LoopFollow
// BatteryAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-17.

import SwiftUI

struct BatteryAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when the phone battery drops below the "
                    + "percentage you set below.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Battery Level",
                footer: "Alert when remaining charge is equal to or below this.",
                title: "Level ≤",
                range: 0 ... 100,
                step: 5,
                unitLabel: "%",
                value: Binding(
                    get: { alarm.threshold ?? 20 },
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
