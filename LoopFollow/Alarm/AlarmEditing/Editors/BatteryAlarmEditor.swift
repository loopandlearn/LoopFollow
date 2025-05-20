// LoopFollow
// BatteryAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-17.

import SwiftUI

struct BatteryAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "This warns you when the phone’s battery gets low, based on the percentage you choose.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Battery Level",
                footer: "This alerts you when the battery drops below this level.",
                title: "Battery Below",
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
            AlarmSnoozeSection(alarm: $alarm, range: 1 ... 24, step: 1)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
