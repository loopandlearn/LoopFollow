// LoopFollow
// NotLoopingAlarmEditor.swift

import SwiftUI

struct NotLoopingAlarmEditor: View {
    @Binding var alarm: Alarm

    private let bgRange: ClosedRange<Double> = 40 ... 300

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when no successful loop has occurred for the time "
                    + "you set below.", alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "No Loop for…",
                footer: "Number of minutes since the last successful loop. "
                    + "When this time has elapsed, the alarm becomes eligible.",
                title: "Elapsed time",
                range: 16 ... 61,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: $alarm.threshold
            )

            AlarmBGLimitSection(
                header: "Low Limit",
                footer: "Alert only if BG is equal to or below this value.",
                toggleText: "Enable low limit",
                pickerTitle: "Below",
                range: bgRange,
                defaultOnValue: 100,
                value: $alarm.belowBG
            )

            AlarmBGLimitSection(
                header: "High Limit",
                footer: "Alert only if BG is equal to or above this value.",
                toggleText: "Enable high limit",
                pickerTitle: "Above",
                range: bgRange,
                defaultOnValue: 160,
                value: $alarm.aboveBG
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
