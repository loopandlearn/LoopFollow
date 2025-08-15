// LoopFollow
// FastRiseAlarmEditor.swift

import SwiftUI

struct FastRiseAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when glucose readings rise rapidly. For example, "
                    + "three straight readings each climbing by at least the amount "
                    + "you set.  Optionally limit alerts to only fire above a certain BG.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Rate of Rise",
                footer: "This is how much the glucose must rise to be considered a fast rise.",
                title: "Rises by",
                range: 3 ... 54,
                value: $alarm.delta
            )

            AlarmStepperSection(
                header: "Consecutive Rises",
                footer: "Number of rises—each meeting the rate above—"
                    + "required before an alert fires.",
                title: "Rises in a row",
                range: 1 ... 3,
                step: 1,
                value: $alarm.monitoringWindow
            )

            AlarmBGLimitSection(
                header: "BG Limit",
                footer: "When enabled, this alert only fires if the glucose is "
                    + "above the limit you set.",
                toggleText: "Use BG Limit",
                pickerTitle: "Rising above",
                range: 40 ... 300,
                defaultOnValue: 200,
                value: $alarm.aboveBG
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
