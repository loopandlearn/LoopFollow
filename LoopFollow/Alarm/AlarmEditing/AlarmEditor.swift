//
//  AlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI

struct AlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        switch alarm.type {
        case .buildExpire:
            BuildExpireAlarmEditor(alarm: $alarm)
        case .high:
            HighBgAlarmEditor(alarm: $alarm)
        case .low:
            LowBgAlarmEditor(alarm: $alarm)
        case .missedReading:
            MissedReadingEditor(alarm: $alarm)
        case .fastDrop:
            FastDropAlarmEditor(alarm: $alarm)

            // TODO: add other condition types here

        default:
            Text("No editor for \(alarm.type.rawValue)")
                .padding()
        }
    }
}
