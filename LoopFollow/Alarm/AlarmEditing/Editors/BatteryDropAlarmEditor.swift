// LoopFollow
// BatteryDropAlarmEditor.swift

import SwiftUI

struct BatteryDropAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "This warns you if your phone’s battery drops quickly, based on the percentage and time you set.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Phone Battery Drop",
                footer: "This alerts you if the phone battery drops by this much or more.",
                title: "Drop Amount",
                range: 5 ... 100,
                step: 5,
                unitLabel: "%",
                value: $alarm.delta
            )

            AlarmStepperSection(
                header: "Over This Time",
                footer: "How far back to look for that drop.",
                title: "Time Window",
                range: 5 ... 30,
                step: 5,
                unitLabel: "min",
                value: $alarm.monitoringWindow
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
