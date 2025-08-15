// LoopFollow
// SensorAgeAlarmEditor.swift

import SwiftUI

struct SensorAgeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Warn me this many hours before the sensor’s 10-day change-over.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Early Reminder",
                footer: "Number of hours before the 10-day mark that the alert " +
                    "will fire.",
                title: "Reminder Time",
                range: 1 ... 24,
                step: 1,
                unitLabel: "hours",
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
