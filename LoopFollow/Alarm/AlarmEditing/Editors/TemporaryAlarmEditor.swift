// LoopFollow
// TemporaryAlarmEditor.swift

import SwiftUI

struct TemporaryAlarmEditor: View {
    @Binding var alarm: Alarm

    // Shared BG range
    private let bgRange: ClosedRange<Double> = 40 ... 300

    var body: some View {
        Group {
            InfoBanner(
                text: "This alert fires once when glucose crosses either of the limits you set below, and then disables itself.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGLimitSection(
                header: "Low Limit",
                footer: "Alert if BG is equal to or below this value.",
                toggleText: "Enable low limit",
                pickerTitle: "Below",
                range: bgRange,
                value: $alarm.belowBG
            )

            AlarmBGLimitSection(
                header: "High Limit",
                footer: "Alert if BG is equal to or above this value.",
                toggleText: "Enable high limit",
                pickerTitle: "Above",
                range: bgRange,
                value: $alarm.aboveBG
            )

            if alarm.belowBG == nil && alarm.aboveBG == nil {
                Text("⚠️ Please enable at least one limit.")
                    .foregroundColor(.red)
            }

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
        }
    }
}
