// LoopFollow
// HighBgAlarmEditor.swift
// Created by Jonas Björkert on 2025-04-26.

import SwiftUI

struct HighBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when your CGM glucose stays above the limit "
                    + "you set below. Use Persistent if you want to ignore brief spikes."
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Threshold",
                footer: "The alarm becomes eligible once any reading is ≥ this value.",
                title: "BG",
                range: 120 ... 350,
                value: Binding(
                    get: { alarm.aboveBG ?? 180 },
                    set: { alarm.aboveBG = $0 }
                )
            )

            AlarmStepperSection(
                header: "Persistent High",
                footer: "How long glucose must remain above the threshold before the "
                    + "alarm actually fires.  Set to 0 for an immediate alert.",
                title: "Persistent for",
                range: 0 ... 120,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: Binding(
                    get: { Double(alarm.persistentMinutes ?? 0) },
                    set: { alarm.persistentMinutes = Int($0) }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(
                alarm: $alarm,
                range: 10 ... 120,
                step: 5
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
