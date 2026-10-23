// LoopFollow
// TimeInRangeModeTests.swift

@testable import LoopFollow
import Testing

/// Serialized: every test mutates the shared `Storage` singleton.
@Suite(.serialized)
struct TimeInRangeModeTests {
    /// Runs `body` with the range mode set to `raw`, restoring the previous value afterwards.
    private func withRangeMode(_ raw: String, _ body: () -> Void) {
        let previous = Storage.shared.timeInRangeModeRaw.value
        Storage.shared.timeInRangeModeRaw.value = raw
        defer { Storage.shared.timeInRangeModeRaw.value = previous }
        body()
    }

    @Test("TIR is 70–180 mg/dL")
    func tirThresholds() {
        withRangeMode(TimeInRangeDisplayMode.tir.rawValue) {
            let t = UnitSettingsStore.shared.effectiveThresholds()
            #expect(t.low == 70 && t.high == 180)
        }
    }

    @Test("TITR is 70–140 mg/dL")
    func titrThresholds() {
        withRangeMode(TimeInRangeDisplayMode.titr.rawValue) {
            let t = UnitSettingsStore.shared.effectiveThresholds()
            #expect(t.low == 70 && t.high == 140)
        }
    }

    @Test("TING is 63–140 mg/dL")
    func tingThresholds() {
        withRangeMode(TimeInRangeDisplayMode.ting.rawValue) {
            let t = UnitSettingsStore.shared.effectiveThresholds()
            #expect(t.low == 63 && t.high == 140)
        }
    }

    @Test("Custom uses the stored low/high lines")
    func customThresholds() {
        let previousLow = Storage.shared.lowLine.value
        let previousHigh = Storage.shared.highLine.value
        Storage.shared.lowLine.value = 80
        Storage.shared.highLine.value = 160
        defer {
            Storage.shared.lowLine.value = previousLow
            Storage.shared.highLine.value = previousHigh
        }
        withRangeMode(TimeInRangeDisplayMode.custom.rawValue) {
            let t = UnitSettingsStore.shared.effectiveThresholds()
            #expect(t.low == 80 && t.high == 160)
        }
    }

    @Test("Unknown stored mode falls back to TIR")
    func unknownModeFallsBackToTIR() {
        withRangeMode("NOT_A_MODE") {
            #expect(UnitSettingsStore.shared.timeInRangeMode == .tir)
            let t = UnitSettingsStore.shared.effectiveThresholds()
            #expect(t.low == 70 && t.high == 180)
        }
    }

    @Test("Every mode has fixed thresholds or is custom")
    func allModesResolve() {
        for mode in TimeInRangeDisplayMode.allCases {
            withRangeMode(mode.rawValue) {
                let t = UnitSettingsStore.shared.effectiveThresholds()
                #expect(t.low < t.high)
            }
        }
    }
}
