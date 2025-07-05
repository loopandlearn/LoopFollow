// LoopFollow
// OverrideStartAlarmEditor.swift
// Created by Jonas Björkert.

import SwiftUI

struct OverrideStartAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when an override begins.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm, hideRepeat: true)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
