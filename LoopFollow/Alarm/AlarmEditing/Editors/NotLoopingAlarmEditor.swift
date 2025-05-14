//
//  NotLoopingAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct NotLoopingAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when no successful loop has occurred for the time "
                    + "you set below.", alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "No Loop for…",
                footer: "Number of minutes since the last successful loop. "
                    + "When this time has elapsed, the alarm becomes eligible.",
                title: "Elapsed time",
                range: 16 ... 61,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { alarm.threshold ?? 31 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmAudioSection(alarm: $alarm)
            AlarmActiveSection(alarm: $alarm)
            AlarmSnoozeSection(
                alarm: $alarm,
                range: 10 ... 120,
                step: 5
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
