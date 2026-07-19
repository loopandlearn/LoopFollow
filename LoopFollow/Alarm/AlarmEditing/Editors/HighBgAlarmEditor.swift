// LoopFollow
// HighBgAlarmEditor.swift

import SwiftUI

struct HighBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when glucose stays above the limit "
                    + "you set below. Use Persistent if you want to ignore brief spikes."
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "High Glucose Limit",
                footer: "The alert becomes eligible once any reading is at or above this value.",
                title: "BG",
                range: 120 ... 350,
                value: $alarm.aboveBG
            )

            AlarmStepperSection(
                header: "Persistent High",
                footer: "How long glucose must remain above the threshold before the "
                    + "alarm actually fires.  Set to 0 for an immediate alert.",
                title: "Persistent for",
                range: 0 ... 120,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: $alarm.persistentMinutes
            )

            Section(
                header: Text("FALLING BG"),
                footer: Text("Stay silent while BG is falling. The alert only sounds "
                    + "when the latest reading is flat or still rising.")
            ) {
                Toggle("Skip if BG is falling", isOn: $alarm.suppressIfFalling)
            }

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
