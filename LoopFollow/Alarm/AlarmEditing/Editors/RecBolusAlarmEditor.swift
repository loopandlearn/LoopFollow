// LoopFollow
// RecBolusAlarmEditor.swift
// Created by Jonas Björkert.

import SwiftUI

struct RecBolusAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when the recommended bolus equals or exceeds the " +
                    "threshold you set below.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Threshold",
                footer: "Alert when recommended bolus is above this value.",
                title: "More than",
                range: 0.1 ... 50,
                step: 0.1,
                unitLabel: "Units",
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
