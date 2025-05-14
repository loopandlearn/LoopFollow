//
//  OverrideEndAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct OverrideEndAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(text: "Alerts when an override ends.", alarmType: alarm.type)

            AlarmGeneralSection(alarm: $alarm)

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm, hideRepeat: true)
            AlarmSnoozeSection(
                alarm: $alarm,
                range: 10 ... 60,
                step: 5
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
