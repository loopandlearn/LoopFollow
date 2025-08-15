// LoopFollow
// PumpChangeAlarmEditor.swift

import SwiftUI

struct PumpChangeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when the pump / cannula is within the time "
                    + "window you choose below (relative to the 3-day change "
                    + "limit).",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Advance Notice",
                footer: "How many hours before the 3-day limit you’d like a reminder.",
                title: "Warning Time",
                range: 1 ... 24,
                step: 1,
                unitLabel: "Hours",
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
