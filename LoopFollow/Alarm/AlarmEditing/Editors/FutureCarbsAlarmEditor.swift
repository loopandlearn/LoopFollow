// LoopFollow
// FutureCarbsAlarmEditor.swift

import SwiftUI

struct FutureCarbsAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when a future-dated carb entry's scheduled time arrives — " +
                    "a reminder to start eating. Use the max lookahead to ignore " +
                    "fat/protein entries that are typically scheduled further ahead.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Max Lookahead",
                footer: "Only track carb entries scheduled up to this many minutes " +
                    "in the future. Entries beyond this window are ignored.",
                title: "Lookahead",
                range: 5 ... 120,
                step: 5,
                unitLabel: "min",
                value: $alarm.threshold
            )

            AlarmStepperSection(
                header: "Minimum Carbs",
                footer: "Ignore carb entries below this amount.",
                title: "At or Above",
                range: 0 ... 50,
                step: 1,
                unitLabel: "g",
                value: $alarm.delta
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
