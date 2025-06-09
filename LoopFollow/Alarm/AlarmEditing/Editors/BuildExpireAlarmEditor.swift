// LoopFollow
// BuildExpireAlarmEditor.swift
// Created by Jonas Björkert on 2025-04-26.

import SwiftUI

struct BuildExpireAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Sends a reminder before the looping-app build you’re following reaches its "
                    + "TestFlight or Xcode expiry date. Works with Trio 0.4 and later."
            )
            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Notice Period",
                footer: "Choose how many days of notice you’d like before the build becomes unusable.",
                title: "Days of notice",
                range: 1 ... 14,
                step: 1,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
