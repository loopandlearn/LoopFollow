// LoopFollow
// COBAlarmEditor.swift

import SwiftUI

struct COBAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when Carbs-on-Board reaches or exceeds the amount you set below.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Carbs on Board Limit",
                footer: "Alert when carbs-on-board is at or above this number.",
                title: "At or Above",
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
