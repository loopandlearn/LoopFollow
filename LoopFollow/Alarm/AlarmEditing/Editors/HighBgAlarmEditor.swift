//
//  HighBgAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-09.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct HighBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Threshold",
                title: "BG",
                range: 120...350,
                value: Binding(
                    get: { alarm.threshold ?? 120 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmStepperSection(
                title: "Persistent",
                range: 0...120,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.persistentMinutes ?? 0) },
                    set: { alarm.persistentMinutes = Int($0) }
                )
            )

            AlarmStepperSection(
                title: "Default Snooze",
                range: 10...120,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.snoozeDuration) },
                    set: { alarm.snoozeDuration = Int($0) }
                )
            )

            AlarmAudioSection(alarm: $alarm)
            AlarmActiveSection(alarm: $alarm)
            AlarmSnoozedUntilSection(alarm: $alarm)

        }
        .navigationTitle(alarm.type.rawValue)
    }
}
