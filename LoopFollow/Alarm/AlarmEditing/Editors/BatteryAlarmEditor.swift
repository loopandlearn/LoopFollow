// LoopFollow
// BatteryAlarmEditor.swift

import SwiftUI

struct BatteryAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "This warns you when the phone’s battery gets low, based on the percentage you choose.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Battery Level",
                footer: "This alerts you when the battery drops to or below this level.",
                title: "Battery Below",
                range: 0 ... 100,
                step: 5,
                unitLabel: "%",
                value: $alarm.threshold
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
