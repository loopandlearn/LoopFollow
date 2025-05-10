//
//  MissedReadingEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-09.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct MissedReadingEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(text: "The app notifies you when no CGM reading has been received for the time you choose below.")

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                footer: "Choose how long the app should wait before alerting.",
                title: "No reading for",
                range: 11...121,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { alarm.threshold ?? 16 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmStepperSection(
                title: "Default Snooze",
                range: 10...180,
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
