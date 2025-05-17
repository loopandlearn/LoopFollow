// LoopFollow
// PumpChangeAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-17.

//
//  PumpChangeAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-17.
//

import SwiftUI

struct PumpChangeAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts once when your pump / cannula is within the time "
                    + "window you choose below (relative to the 3-day change "
                    + "limit).  After it fires once it disables itself.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Advance Notice",
                footer: "How many hours before the 3-day limit the alert "
                    + "should fire.  Set to 12 hours, for example, to get a "
                    + "reminder half a day in advance.",
                title: "Warn hours",
                range: 1 ... 24,
                step: 1,
                value: Binding(
                    get: { alarm.threshold ?? 12 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm, range: 1 ... 24, step: 1)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
