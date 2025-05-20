// LoopFollow
// AlarmEditor.swift
// Created by Jonas Björkert on 2025-04-26.

import SwiftUI

struct AlarmEditor: View {
    @Binding var alarm: Alarm
    var isNew: Bool = false
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            innerEditor()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isNew {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                onDone()
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                onCancel()
                                dismiss()
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func innerEditor() -> some View {
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
        case .notLooping:
            NotLoopingAlarmEditor(alarm: $alarm)
        case .overrideStart:
            OverrideStartAlarmEditor(alarm: $alarm)
        case .overrideEnd:
            OverrideEndAlarmEditor(alarm: $alarm)
        case .tempTargetStart:
            TempTargetStartAlarmEditor(alarm: $alarm)
        case .tempTargetEnd:
            TempTargetEndAlarmEditor(alarm: $alarm)
        case .recBolus:
            RecBolusAlarmEditor(alarm: $alarm)
        case .cob:
            COBAlarmEditor(alarm: $alarm)
        case .fastRise:
            FastRiseAlarmEditor(alarm: $alarm)
        case .temporary:
            TemporaryAlarmEditor(alarm: $alarm)
        case .sensorChange:
            SensorAgeAlarmEditor(alarm: $alarm)
        case .pumpChange:
            PumpChangeAlarmEditor(alarm: $alarm)
        case .pump:
            PumpVolumeAlarmEditor(alarm: $alarm)
        case .iob:
            IOBAlarmEditor(alarm: $alarm)
        case .battery:
            BatteryAlarmEditor(alarm: $alarm)
        /* TODO: add other condition types here */
        default:
            Text("No editor for \(alarm.type.rawValue)")
                .padding()
        }
    }
}
