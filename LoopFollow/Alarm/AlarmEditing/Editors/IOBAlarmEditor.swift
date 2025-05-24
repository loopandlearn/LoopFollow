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
                value: Binding(
                    get: { alarm.delta ?? 1.0 },
                    set: { alarm.delta = $0 }
                )
            )

            AlarmStepperSection(
                header: "Bolus Count",
                footer: "Number of qualifying boluses needed to trigger.",
                title: "Count",
                range: 1 ... 10,
                step: 1,
                unitLabel: "Boluses",
                value: Binding(
                    get: { Double(alarm.monitoringWindow ?? 2) },
                    set: { alarm.monitoringWindow = Int($0) }
                )
            )

            AlarmStepperSection(
                header: "Time Window",
                footer: "How far back to look for those boluses.",
                title: "Time",
                range: 5 ... 120,
                step: 5,
                unitLabel: "min",
                value: Binding(
                    get: { Double(alarm.predictiveMinutes ?? 30) },
                    set: { alarm.predictiveMinutes = Int($0) }
                )
            )

            AlarmStepperSection(
                header: "Insulin On Board",
                footer: "Alert if current IOB or total boluses reach this.",
                title: "IOB Above",
                range: 1 ... 20,
                step: 0.5,
                unitLabel: "Units",
                value: Binding(
                    get: { alarm.threshold ?? 6 },
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
