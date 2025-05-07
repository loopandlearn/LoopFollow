//
//  BuildExpireAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct BuildExpireAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
          AlarmGeneralSection(alarm: $alarm)

          AlarmStepperSection(
            title: "Expires In",
            range: 1...14,
            step: 1,
            unitLabel: alarm.type.timeUnit.label,
            value: Binding(
              get: { alarm.threshold ?? 1 },
              set: { alarm.threshold = $0 }
            )
          )

          AlarmSnoozeSection(
            title: "Default Snooze",
            range: 1...14,
            step: 1,
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
