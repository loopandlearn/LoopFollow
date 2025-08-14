// LoopFollow
// FastDropAlarmEditor.swift

import SwiftUI

struct FastDropAlarmEditor: View {
    @Binding var alarm: Alarm

    @State private var useLimit: Bool = false

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when glucose readings drop rapidly. For example, three straight readings each falling by at least the amount you set. Optionally limit alerts to only fire below a certain BG level."
            )
            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Rate of Fall",
                footer: "This is how much the glucose must drop to be considered a fast drop.",
                title: "Falls by",
                range: 3 ... 54,
                value: $alarm.delta
            )

            AlarmStepperSection(
                header: "Consecutive Drops",
                footer: "Number of drops—each meeting the rate above—required before an alert fires.",
                title: "Number of Drops",
                range: 1 ... 3,
                step: 1,
                value: $alarm.monitoringWindow
            )

            AlarmBGLimitSection(
                header: "BG Limit",
                footer: "When enabled, this alert only fires if the glucose is below the limit you set.",
                toggleText: "Use BG Limit",
                pickerTitle: "Dropping below",
                range: 40 ... 300,
                defaultOnValue: 120,
                value: $alarm.belowBG
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
