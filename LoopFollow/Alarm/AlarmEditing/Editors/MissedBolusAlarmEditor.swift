// LoopFollow
// MissedBolusAlarmEditor.swift

import SwiftUI

struct MissedBolusAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Group {
            InfoBanner(
                text: "Alerts when carbs are logged but no bolus is delivered " +
                    "within the delay below.  Allows small-carb / treatment " +
                    "exclusions and pre-bolus detection.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Delay",
                footer: "Minutes to wait after the carb entry before checking " +
                    "for a bolus.",
                title: "Delay",
                range: 5 ... 60,
                step: 5,
                unitLabel: "min",
                value: $alarm.monitoringWindow
            )

            AlarmStepperSection(
                header: "Pre-bolus",
                footer: "Count boluses given up to this many minutes before " +
                    "the carb entry as valid.",
                title: "Pre-Bolus Time",
                range: 0 ... 45,
                step: 5,
                unitLabel: "min",
                value: $alarm.predictiveMinutes
            )

            AlarmStepperSection(
                header: "Ignore small boluses",
                footer: "Boluses at or below this size are ignored.",
                title: "Ignore at or below",
                range: 0.05 ... 2,
                step: 0.05,
                unitLabel: "Units",
                value: $alarm.delta
            )

            AlarmStepperSection(
                header: "Ignore small carbs",
                footer: "Carb entries at or below this amount will not trigger the alarm.",
                title: "At or Below",
                range: 0 ... 15,
                step: 1,
                unitLabel: "Grams",
                value: $alarm.threshold
            )

            AlarmBGLimitSection(
                header: "Ignore low BG",
                footer: "Only alert if the current BG is above this value.",
                toggleText: "Use BG Limit",
                pickerTitle: "Above",
                range: 40 ... 140,
                defaultOnValue: 70,
                value: $alarm.aboveBG
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm)
        }
    }
}
