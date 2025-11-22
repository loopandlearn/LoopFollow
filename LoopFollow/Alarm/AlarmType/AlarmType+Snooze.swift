// LoopFollow
// AlarmType+Snooze.swift

import Foundation

extension AlarmType {
    /// What “unit” we use for snoozeDuration for this alarmType.
    var snoozeTimeUnit: TimeUnit {
        switch self {
        case .buildExpire:
            return .day
        case .low, .high, .fastDrop, .fastRise,
             .missedReading, .notLooping, .missedBolus,
             .recBolus,
             .overrideStart, .overrideEnd, .tempTargetStart,
             .tempTargetEnd:
            return .minute
        case .battery, .batteryDrop, .pumpBattery, .sensorChange, .pumpChange, .cob, .iob,
             .pump:
            return .hour
        case .temporary:
            return .none
        }
    }

    /// Valid values you may pick in the UI (`Stepper`, `Picker`, etc.).
    /// The *lower* bound may be 0 if you want “Acknowledge”.
    var snoozeRange: ClosedRange<Int> {
        switch snoozeTimeUnit {
        case .minute:
            return (canAcknowledge ? 0 : 5) ... 120
        case .hour:
            return (canAcknowledge ? 0 : 1) ... 24
        case .day:
            return (canAcknowledge ? 0 : 1) ... 10
        case .none:
            return 0 ... 0
        }
    }

    /// How much the value should grow/shrink when you tap the `Stepper`.
    var snoozeStep: Int {
        switch snoozeTimeUnit {
        case .minute: return 5
        default: return 1
        }
    }
}
