// LoopFollow
// AlarmEditor.swift

import SwiftUI

struct AlarmEditor: View {
    @Binding var alarm: Alarm
    var isNew: Bool = false
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                innerEditorBody()
                if !isNew {
                    DeleteAlarmSection {
                        onDelete()
                        dismiss()
                    }
                }
            }.navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDone()
                            dismiss()
                        }
                    }
                    if isNew {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                onCancel()
                                dismiss()
                            }
                        }
                    }
                }
                .navigationTitle(alarm.type.rawValue)
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
    }

    private func innerEditor() -> some View {
        Form {
            innerEditorBody()

            DeleteAlarmSection {
                onDelete()
                dismiss()
            }
        }
    }

    /// Break the old `switch` out into its own helper so the call above is tidy.
    @ViewBuilder
    private func innerEditorBody() -> some View {
        switch alarm.type {
        case .buildExpire: BuildExpireAlarmEditor(alarm: $alarm)
        case .high: HighBgAlarmEditor(alarm: $alarm)
        case .low: LowBgAlarmEditor(alarm: $alarm)
        case .missedReading: MissedReadingEditor(alarm: $alarm)
        case .fastDrop: FastDropAlarmEditor(alarm: $alarm)
        case .notLooping: NotLoopingAlarmEditor(alarm: $alarm)
        case .overrideStart: OverrideStartAlarmEditor(alarm: $alarm)
        case .overrideEnd: OverrideEndAlarmEditor(alarm: $alarm)
        case .tempTargetStart: TempTargetStartAlarmEditor(alarm: $alarm)
        case .tempTargetEnd: TempTargetEndAlarmEditor(alarm: $alarm)
        case .recBolus: RecBolusAlarmEditor(alarm: $alarm)
        case .cob: COBAlarmEditor(alarm: $alarm)
        case .fastRise: FastRiseAlarmEditor(alarm: $alarm)
        case .temporary: TemporaryAlarmEditor(alarm: $alarm)
        case .sensorChange: SensorAgeAlarmEditor(alarm: $alarm)
        case .pumpChange: PumpChangeAlarmEditor(alarm: $alarm)
        case .pump: PumpVolumeAlarmEditor(alarm: $alarm)
        case .pumpBattery: PumpBatteryAlarmEditor(alarm: $alarm)
        case .iob: IOBAlarmEditor(alarm: $alarm)
        case .battery: PhoneBatteryAlarmEditor(alarm: $alarm)
        case .batteryDrop: BatteryDropAlarmEditor(alarm: $alarm)
        case .missedBolus: MissedBolusAlarmEditor(alarm: $alarm)
        }
    }
}
