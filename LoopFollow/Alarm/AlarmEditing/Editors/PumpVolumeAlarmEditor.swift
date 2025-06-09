// LoopFollow
// PumpVolumeAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-17.

import SwiftUI

struct PumpVolumeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "This warns you when the insulin pump is running low on insulin.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Trigger Level",
                footer: "An alert fires once the reservoir is at this value "
                    + "or lower.",
                title: "Reservoir Below",
                range: 1 ... 50,
                step: 1,
                unitLabel: "Units",
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
