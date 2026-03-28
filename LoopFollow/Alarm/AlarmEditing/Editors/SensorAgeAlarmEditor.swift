// LoopFollow
// SensorAgeAlarmEditor.swift

import SwiftUI

struct SensorAgeAlarmEditor: View {
    @Binding var alarm: Alarm

    private var lifetimeDays: Int {
        alarm.sensorLifetimeDays ?? 10
    }

    private var lifetimeBinding: Binding<Int?> {
        Binding(
            get: { alarm.sensorLifetimeDays ?? 10 },
            set: { alarm.sensorLifetimeDays = $0 }
        )
    }

    var body: some View {
        Group {
            InfoBanner(
                text: "Warn me before the sensor’s \(lifetimeDays)-day change-over.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Sensor Lifetime",
                footer: "Number of days your CGM sensor lasts " +
                    "(e.g. 10 for Dexcom G6, 15 for G7 15-day).",
                title: "Lifetime",
                range: 7 ... 15,
                step: 1,
                unitLabel: "days",
                value: lifetimeBinding
            )

            AlarmStepperSection(
                header: "Early Reminder",
                footer: "Number of hours before the \(lifetimeDays)-day mark that the alert " +
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
