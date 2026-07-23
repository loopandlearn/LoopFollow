// LoopFollow
// DBSizeAlarmEditor.swift

import SwiftUI

struct DBSizeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "This warns you when the Nightscout database has filled the percentage you choose. Nightscout measures the used space against its own DBSIZE_MAX setting, which is 496 MiB unless the site owner changed it, so the percentage is only meaningful when that setting matches the real hosting limit.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Database Size",
                footer: "This alerts you when the database reaches or exceeds this percentage of the limit configured on the Nightscout site.",
                title: "At or Above",
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
