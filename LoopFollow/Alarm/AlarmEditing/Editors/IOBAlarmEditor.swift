// LoopFollow
// IOBAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-19.

import SwiftUI

struct IOBAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when insulin-on-board is high, or when several "
                    + "boluses in quick succession exceed the limits you set.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Boluses Size Limit",
                footer: "This counts only boluses larger than this size.",
                title: "Above",
                range: 0.1 ... 20,
                step: 0.1,
                unitLabel: "Units",
                value: $alarm.delta
            )

            AlarmStepperSection(
                header: "Bolus Count",
                footer: "Number of qualifying boluses needed to trigger.",
                title: "Count",
                range: 1 ... 10,
                step: 1,
                unitLabel: "Boluses",
                value: $alarm.monitoringWindow
            )

            AlarmStepperSection(
                header: "Time Window",
                footer: "How far back to look for those boluses.",
                title: "Time",
                range: 5 ... 120,
                step: 5,
                unitLabel: "min",
                value: $alarm.predictiveMinutes
            )

            AlarmStepperSection(
                header: "Insulin On Board",
                footer: "Alert if current IOB or total boluses reach this.",
                title: "IOB Above",
                range: 1 ... 20,
                step: 0.5,
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
