// LoopFollow
// TempTargetEndAlarmEditor.swift

import SwiftUI

struct TempTargetEndAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(text: "Alerts when a temp target ends, with an optional early warning before the scheduled end.", alarmType: alarm.type)

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Early Warning",
                footer: "Also alert this many minutes before the temp target "
                    + "is scheduled to end.  Set to 0 to alert only when it ends.",
                title: "Warn before end",
                range: 0 ... 30,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: $alarm.predictiveMinutes
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm, hideRepeat: true)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
