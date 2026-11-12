// LoopFollow
// BGDisplayPrecisionTests.swift

import Foundation
@testable import LoopFollow
import Testing

/// In mmol/L, two mg/dL readings that display the same value must get the same
/// alarm result, and a threshold picked as X.X mmol/L must fire for a reading
/// that displays as X.X, regardless of which conversion factor stored it.
@Suite(.serialized)
struct BGDisplayPrecisionTests {
    private func withMmol(_ body: () -> Void) {
        let previous = Storage.shared.units.value
        Storage.shared.units.value = GlucoseDisplayUnit.mmolL.rawValue
        defer { Storage.shared.units.value = previous }
        body()
    }

    private func highAlarm(aboveBG: Double) -> Alarm {
        var alarm = Alarm(type: .high)
        alarm.aboveBG = aboveBG
        return alarm
    }

    private func fires(_ alarm: Alarm, sgv: Int) -> Bool {
        let data = AlarmData.withReadings([sgv])
        if alarm.type == .high {
            return HighBGCondition().evaluate(alarm: alarm, data: data, now: Date())
        }
        return LowBGCondition().evaluate(alarm: alarm, data: data, now: Date())
    }

    @Test("high 10.0 mmol/L fires for both mg/dL readings that display 10.0")
    func highBoundaryDisplaysAsLimit() {
        withMmol {
            // 10.0 mmol/L stored with the shared factor and with the old x18 picker factor.
            for stored in [10.0 * GlucoseConversion.mmolToMgDl, 10.0 * 18] {
                let alarm = highAlarm(aboveBG: stored)
                #expect(!fires(alarm, sgv: 179))
                #expect(fires(alarm, sgv: 180))
                #expect(fires(alarm, sgv: 181))
                #expect(fires(alarm, sgv: 182))
            }
        }
    }

    @Test("high 7.8 mmol/L fires at 140, which displays 7.8, even when stored as 140.4")
    func highLegacyPickerValue() {
        withMmol {
            let alarm = highAlarm(aboveBG: 7.8 * 18)
            #expect(!fires(alarm, sgv: 139))
            #expect(fires(alarm, sgv: 140))
            #expect(fires(alarm, sgv: 141))
        }
    }

    @Test("low 3.9 mmol/L fires for both mg/dL readings that display 3.9")
    func lowBoundaryDisplaysAsLimit() {
        withMmol {
            for stored in [3.9 * GlucoseConversion.mmolToMgDl, 3.9 * 18] {
                let alarm = Alarm.low(belowBG: stored)
                #expect(fires(alarm, sgv: 69))
                #expect(fires(alarm, sgv: 70))
                #expect(fires(alarm, sgv: 71))
                #expect(!fires(alarm, sgv: 72))
            }
        }
    }

    @Test("mg/dL keeps exact integer comparison")
    func mgdlUnchanged() {
        let previous = Storage.shared.units.value
        Storage.shared.units.value = GlucoseDisplayUnit.mgdL.rawValue
        defer { Storage.shared.units.value = previous }

        #expect(fires(highAlarm(aboveBG: 180), sgv: 180))
        #expect(!fires(highAlarm(aboveBG: 180), sgv: 179))
        #expect(fires(Alarm.low(belowBG: 70), sgv: 70))
        #expect(!fires(Alarm.low(belowBG: 70), sgv: 71))
    }

    @Test("every mmol/L picker value round-trips to the value that was picked")
    func pickerValuesRoundTrip() {
        withMmol {
            for tenths in 20 ... 400 {
                let picked = Double(tenths) / 10
                let stored = picked * GlucoseConversion.mmolToMgDl
                let normalized = UnitSettingsStore.shared.normalizeToDisplayPrecision(stored)
                #expect(Int((normalized * 10).rounded()) == tenths)
            }
        }
    }
}
