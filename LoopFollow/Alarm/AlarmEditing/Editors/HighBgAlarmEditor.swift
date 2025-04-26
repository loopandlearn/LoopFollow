//
//  HighBgAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI

struct HighBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {/*
            AlarmNameField(alarm: $alarm)
            EnabledToggle(alarm: $alarm)
            ValueStepper(
                title: "BG Above",
                value: Binding(
                    get: { Double(alarm.threshold ?? 0) },
                    set: { alarm.threshold = Float($0) }
                ),
                range: 0...500, step: 1,
                formatter: { "\(Int($0))" }
            )
            DayNightToggle(alarm: $alarm)
            SoundPicker(alarm: $alarm)
            SnoozeDatePicker(alarm: $alarm)
            SnoozeDurationStepper(alarm: $alarm)*/
        }
        .navigationTitle("High BG Alert")
    }
}
