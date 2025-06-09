// LoopFollow
// LowBgAlarmEditor.swift
// Created by Jonas Björkert on 2025-04-26.

import SwiftUI

struct LowBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(text: "This warns you if the glucose is too low now or might be soon, based on predictions. Note: predictions is currently not available for Trio.")

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Low Limit",
                footer: "Alert when any reading or prediction is at or below this value.",
                title: "BG",
                range: 40 ... 150,
                value: $alarm.belowBG
            )

            AlarmStepperSection(
                header: "PERSISTENCE",
                footer: "Glucose must stay below the threshold for this many minutes "
                    + "before the alert sounds. Set 0 to alert immediately.",
                title: "Persistent",
                range: 0 ... 120,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: $alarm.persistentMinutes
            )

            AlarmStepperSection(
                header: "PREDICTION",
                footer: "Look ahead this many minutes in Loop’s prediction; "
                    + "if any future value is at or below the threshold, "
                    + "you’ll be warned early. Set 0 to disable.",
                title: "Predictive",
                range: 0 ... 60,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: $alarm.predictiveMinutes
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
