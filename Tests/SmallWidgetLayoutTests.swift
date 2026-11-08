// LoopFollow
// SmallWidgetLayoutTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct SmallWidgetLayoutTests {
    @Test("Wide CarPlay gets the tight layout when the setting is on")
    func wideCarPlayUsesTightLayout() {
        #expect(SmallWidgetLayout.usesTightLayout(enabled: true, width: 240))
    }

    @Test("With the setting off, wide CarPlay keeps the single slot")
    func settingOffKeepsSlot() {
        #expect(!SmallWidgetLayout.usesTightLayout(enabled: false, width: 240))
    }

    @Test("Narrow CarPlay and every Watch size keep the single slot", arguments: [170.0, 152, 165, 173, 184, 191, 198])
    func otherSurfacesKeepSlot(width: Double) {
        #expect(!SmallWidgetLayout.usesTightLayout(enabled: true, width: CGFloat(width)))
    }

    @Test("With the status line on, the right slot doesn't offer what the line shows")
    func statusLineHidesItsValues() {
        let options = LiveActivitySlotOption.smallWidgetCases(showStatusLine: true)
        #expect(!options.contains(.iob))
        #expect(!options.contains(.cob))
        #expect(!options.contains(.override))
        #expect(options.contains(.projectedBG))
    }

    @Test("With the status line off, the right slot offers every option")
    func statusLineOffOffersAll() {
        #expect(LiveActivitySlotOption.smallWidgetCases(showStatusLine: false) == LiveActivitySlotOption.allCases)
    }

    private func snapshot(basalRate: String) -> GlucoseSnapshot {
        GlucoseSnapshot(
            glucose: 120,
            delta: 0,
            trend: .flat,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            iob: nil,
            cob: nil,
            projected: nil,
            basalRate: basalRate,
            unit: .mgdl,
            isNotLooping: false
        )
    }

    @Test("A temp basal shows only the rate running now")
    func tempBasalShowsActualRate() {
        #expect(snapshot(basalRate: "0.85 → 1.2").activeBasalRate == "1.2")
    }

    @Test("A scheduled basal is unchanged")
    func scheduledBasalUnchanged() {
        #expect(snapshot(basalRate: "0.85").activeBasalRate == "0.85")
    }

    @Test("A missing basal stays empty")
    func missingBasalStaysEmpty() {
        #expect(snapshot(basalRate: "").activeBasalRate.isEmpty)
    }
}
