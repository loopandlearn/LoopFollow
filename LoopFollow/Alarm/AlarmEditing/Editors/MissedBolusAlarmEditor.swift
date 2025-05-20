// LoopFollow
// MissedBolusAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-20.

import SwiftUI

struct MissedBolusAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when carbs are logged but no bolus is delivered " +
                    "within the delay below.  Allows small-carb / treatment " +
                    "exclusions and pre-bolus detection.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Delay",
                footer: "Minutes to wait after the carb entry before checking " +
                    "for a bolus.",
                title: "Delay",
                range: 5 ... 60,
                step: 5,
                unitLabel: "min",
                value: Binding(
                    get: { Double(alarm.monitoringWindow ?? 15) },
                    set: { alarm.monitoringWindow = Int($0) }
                )
            )

            AlarmStepperSection(
                header: "Pre-bolus",
                footer: "Count boluses given up to this many minutes before " +
                    "the carb entry as valid.",
                title: "Pre-Bolus Time",
                range: 0 ... 45,
                step: 5,
                unitLabel: "min",
                value: Binding(
                    get: { Double(alarm.predictiveMinutes ?? 15) },
                    set: { alarm.predictiveMinutes = Int($0) }
                )
            )

            AlarmStepperSection(
                header: "Ignore small boluses",
                footer: "Boluses below this size are ignored.",
                title: "Ignore below",
                range: 0.05 ... 2,
                step: 0.05,
                unitLabel: "Units",
                value: Binding(
                    get: { alarm.delta ?? 0.1 },
                    set: { alarm.delta = $0 }
                )
            )

            AlarmStepperSection(
                header: "Ignore small carbs",
                footer: "Carb entries below this amount will not trigger the alarm.",
                title: "Below",
                range: 0 ... 15,
                step: 1,
                unitLabel: "Grams",
                value: Binding(
                    get: { alarm.threshold ?? 4 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmBGLimitSection(
                header: "Ignore low BG",
                footer: "Only alert if the current BG is above this value.",
                toggleText: "Use BG Limit",
                pickerTitle: "Above",
                range: 40 ... 140,
                value: $alarm.aboveBG
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm, range: 5 ... 60, step: 5)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
