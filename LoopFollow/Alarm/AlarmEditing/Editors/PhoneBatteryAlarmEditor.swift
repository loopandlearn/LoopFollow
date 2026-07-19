// LoopFollow
// PhoneBatteryAlarmEditor.swift

import SwiftUI

struct PhoneBatteryAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "This warns you when the phone's battery gets low, based on the percentage you choose.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Phone Battery Level",
                footer: "This alerts you when the phone battery drops to or below this level.",
                title: "At or Below",
                range: 0 ... 100,
                step: 5,
                unitLabel: "%",
                value: $alarm.threshold
            )

            Section(
                header: Text("CHARGING"),
                footer: Text("Stay silent while the phone is charging. Requires the "
                    + "uploader to report charging status; if it doesn't, the alert still sounds.")
            ) {
                Toggle("Skip while charging", isOn: $alarm.suppressIfCharging)
            }

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
