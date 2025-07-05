// LoopFollow
// COBAlarmEditor.swift
// Created by Jonas Björkert.

import SwiftUI

struct COBAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when Carbs-on-Board exceeds the amount you set below.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Carbs on Board Limit",
                footer: "Alert when carbs-on-board is above this number.",
                title: "Above",
                range: 1 ... 200,
                step: 1,
                unitLabel: "g",
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)

            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
