// LoopFollow
// BGChartModel.swift

import Foundation
import SwiftUI

/// Interaction state shared between the main chart (which owns the gestures)
/// and the small overview chart (which shows a viewport box and navigates on
/// tap). Kept separate from BGChartModel so high-frequency pan/zoom writes
/// don't invalidate views that only observe the data.
final class BGChartInteraction: ObservableObject {
    /// Date at the leading (left) edge of the main chart's visible window.
    @Published var scrollPosition: Date
    /// Length of the visible x-axis window in seconds.
    @Published var visibleSeconds: TimeInterval
    /// True while the main chart should keep auto-scrolling to "now"; cleared
    /// when the user pans back into history, re-armed when they return to the edge.
    @Published var followLatest: Bool = true

    init() {
        let seconds = Self.visibleSeconds(forScale: Storage.shared.chartScaleX.value)
        visibleSeconds = seconds
        scrollPosition = Date().addingTimeInterval(-seconds * 0.7)
    }

    /// Maps the legacy persisted zoom scale (danielgindi-era semantics:
    /// 24 h divided by the scale factor) to a visible-window length.
    static func visibleSeconds(forScale scale: Double) -> TimeInterval {
        guard scale > 0 else { return 6 * 3600 }
        return min(max(24 * 3600 / scale, 15 * 60), 24 * 3600)
    }

    /// Persists the current zoom back into the legacy scale representation.
    func persistZoom() {
        Storage.shared.chartScaleX.value = 24 * 3600 / visibleSeconds
    }
}

final class BGChartModel: ObservableObject {
    struct BGPoint: Identifiable {
        let date: Date
        let value: Double
        let color: Color
        var id: Double { date.timeIntervalSince1970 }
    }

    struct TreatmentPoint: Identifiable {
        let date: Date
        let value: Double
        let sgv: Double
        let label: String
        let pillText: String
        var id: Double { date.timeIntervalSince1970 }
    }

    struct BasalStep: Identifiable {
        let start: Date
        let end: Date
        let rate: Double
        var id: TimeInterval { start.timeIntervalSince1970 }
    }

    struct ScheduledBasalPoint: Identifiable {
        let date: Date
        let rate: Double
        var id: TimeInterval { date.timeIntervalSince1970 }
    }

    struct BandRect: Identifiable {
        let start: Date
        let end: Date
        let yBottom: Double
        let yTop: Double
        let pillText: String
        var id: String { "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)" }
    }

    struct ConePoint: Identifiable {
        let date: Date
        let yMin: Double
        let yMax: Double
        var id: Double { date.timeIntervalSince1970 }
    }

    /// A maximal stretch of consecutive BG readings sharing one range color.
    /// Each run renders as a single LineMark series; runs share their boundary
    /// point so the line stays visually continuous across color changes.
    /// (One series per run — tens per day — instead of one per segment, which
    /// was a Swift Charts layout hotspot at hundreds of series.)
    struct BGRun: Identifiable {
        let id: Int
        let color: Color
        let points: [BGPoint]
    }

    @Published var bg: [BGPoint] = []
    @Published var bgRuns: [BGRun] = []
    @Published var yesterday: [BGPoint] = []
    @Published var prediction: [BGPoint] = []
    @Published var ztPrediction: [BGPoint] = []
    @Published var iobPrediction: [BGPoint] = []
    @Published var cobPrediction: [BGPoint] = []
    @Published var uamPrediction: [BGPoint] = []

    /// Prediction cone band (min/max envelope). Set by updateOpenAPSPredictionDisplay;
    /// preserved across rebuild() since it has no source array on the view controller.
    /// The didSet keeps the canvas generation in sync for call sites that assign the
    /// cone directly without triggering a rebuild.
    @Published var cone: [ConePoint] = [] {
        didSet { generation &+= 1 }
    }

    @Published var basal: [BasalStep] = []
    @Published var basalScheduled: [ScheduledBasalPoint] = []

    @Published var boluses: [TreatmentPoint] = []
    @Published var carbs: [TreatmentPoint] = []
    @Published var smbs: [TreatmentPoint] = []
    @Published var bgChecks: [TreatmentPoint] = []
    @Published var suspends: [TreatmentPoint] = []
    @Published var resumes: [TreatmentPoint] = []
    @Published var sensorStarts: [TreatmentPoint] = []
    @Published var notes: [TreatmentPoint] = []

    @Published var overrides: [BandRect] = []
    @Published var tempTargets: [BandRect] = []

    // Backend-aware band colors: Loop draws overrides green / temp targets purple,
    // Trio (and other OpenAPS backends) use the inverse. Mirrors TreatmentGraphColors.
    @Published var overrideColor: Color = .green
    @Published var tempTargetColor: Color = .purple

    @Published var maxBG: Double = 250
    @Published var maxBasal: Double = 5
    @Published var lowLine: Double = 70
    @Published var highLine: Double = 180
    @Published var domainStart: Date = .init(timeIntervalSince1970: 0)
    @Published var domainEnd: Date = .init(timeIntervalSince1970: 0)

    @Published var now: Date = .init()
    @Published var diaMarkers: [Date] = []
    @Published var midnightMarkers: [Date] = []
    @Published var thirtyMinMark: Date? = nil
    @Published var ninetyMinMark: Date? = nil

    /// Shared pan/zoom/follow state (see BGChartInteraction). A separate object so
    /// per-frame gesture writes don't invalidate views that only observe the data.
    let interaction = BGChartInteraction()

    /// Monotonic data version. Bumped whenever chart data changes; the chart
    /// canvases use it (instead of comparing arrays) to decide whether a
    /// re-layout is needed, so panning — which changes none of the data — can
    /// provably skip their bodies.
    private(set) var generation: Int = 0

    private var rebuildScheduled = false

    @Published var showLines: Bool = true
    @Published var showDots: Bool = true
    @Published var showDIA: Bool = true
    @Published var show30Min: Bool = false
    @Published var show90Min: Bool = false
    @Published var showMidnight: Bool = false

    private static let doseFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = false
        nf.minimumIntegerDigits = 0
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf
    }()

    private func formatDose(_ value: Double) -> String {
        Self.doseFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func colorFor(_ sgv: Int) -> Color {
        if Double(sgv) >= Storage.shared.highLine.value {
            return .yellow
        } else if Double(sgv) <= Storage.shared.lowLine.value {
            return .red
        } else {
            return .green
        }
    }

    /// Groups consecutive same-colored readings into line runs (see BGRun).
    /// The segment between two points takes the color of the earlier point,
    /// matching the legacy per-segment coloring.
    private static func makeRuns(_ points: [BGPoint]) -> [BGRun] {
        guard let first = points.first else { return [] }
        var runs: [BGRun] = []
        var runColor = first.color
        var runPoints: [BGPoint] = [first]
        for pt in points.dropFirst() {
            runPoints.append(pt)
            if pt.color != runColor {
                runs.append(BGRun(id: runs.count, color: runColor, points: runPoints))
                runPoints = [pt]
                runColor = pt.color
            }
        }
        if runPoints.count > 1 {
            runs.append(BGRun(id: runs.count, color: runColor, points: runPoints))
        }
        return runs
    }

    /// Schedules a rebuild, coalescing bursts: a refresh cycle calls a dozen
    /// legacy update*Graph() shims back-to-back, and rebuilding once per
    /// runloop turn is enough.
    func rebuild() {
        guard !rebuildScheduled else {
            return
        }
        rebuildScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.rebuildScheduled = false
            self.performRebuild()
        }
    }

    private func performRebuild() {
        guard let vc = MainViewController.shared else { return }

        let maxBGValue = Double(vc.calculateMaxBgGraphValue())
        maxBG = max(maxBGValue, Storage.shared.minBGScale.value)
        lowLine = Storage.shared.lowLine.value
        highLine = Storage.shared.highLine.value

        showLines = Storage.shared.showLines.value
        showDots = Storage.shared.showDots.value
        showDIA = Storage.shared.showDIALines.value
        show30Min = Storage.shared.show30MinLine.value
        show90Min = Storage.shared.show90MinLine.value
        showMidnight = Storage.shared.showMidnightLines.value

        let isLoop = Storage.shared.device.value == "Loop"
        overrideColor = isLoop ? .green : .purple
        tempTargetColor = isLoop ? .purple : .green

        // Clamp plotted BG to the display range (matches the legacy chart and #600);
        // color is still keyed off the true reading.
        let minDisplay = globalVariables.minDisplayGlucose
        let maxDisplay = globalVariables.maxDisplayGlucose
        func clampSgv(_ sgv: Int) -> Double { Double(min(max(sgv, minDisplay), maxDisplay)) }

        bg = vc.bgData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: clampSgv($0.sgv), color: colorFor($0.sgv)) }
        bgRuns = Self.makeRuns(bg)

        // Yesterday comparison overlay (#665): already +24h shifted, dimmed gray, no dots.
        if Storage.shared.showYesterdayLine.value {
            yesterday = vc.yesterdayBGData.map {
                BGPoint(date: Date(timeIntervalSince1970: $0.date), value: clampSgv($0.sgv), color: Color(.systemGray).opacity(0.4))
            }
        } else {
            yesterday = []
        }

        prediction = vc.predictionData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), color: .purple) }
        ztPrediction = vc.ztPredictionData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), color: .purple) }
        iobPrediction = vc.iobPredictionData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), color: .purple) }
        cobPrediction = vc.cobPredictionData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), color: .purple) }
        uamPrediction = vc.uamPredictionData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), color: .purple) }

        boluses = vc.bolusData.map {
            let dose = self.formatDose($0.value)
            return TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: $0.value,
                sgv: Double($0.sgv),
                label: dose,
                pillText: "Bolus\n\(dose)U"
            )
        }
        carbs = vc.carbData.map {
            let grams = Int($0.value)
            var label = "\(grams)"
            if $0.absorptionTime > 0, Storage.shared.showAbsorption.value {
                label += " \($0.absorptionTime / 60)h"
            }
            return TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: $0.value,
                sgv: Double($0.sgv),
                label: label,
                pillText: "Carbs\n\(grams)g"
            )
        }
        smbs = vc.smbData.map {
            let dose = self.formatDose($0.value)
            return TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: $0.value,
                sgv: Double($0.sgv),
                label: dose,
                pillText: "SMB\n\(dose)U"
            )
        }
        bgChecks = vc.bgCheckData.map {
            TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: Double($0.sgv),
                sgv: Double($0.sgv),
                label: "",
                pillText: "BG Check\n\(Localizer.toDisplayUnits(String($0.sgv)))"
            )
        }
        suspends = vc.suspendGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: "", pillText: "Suspend")
        }
        resumes = vc.resumeGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: "", pillText: "Resume")
        }
        sensorStarts = vc.sensorStartGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: "", pillText: "Sensor Start")
        }
        notes = vc.noteGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: $0.note, pillText: $0.note)
        }

        basalScheduled = vc.basalScheduleData.map {
            ScheduledBasalPoint(date: Date(timeIntervalSince1970: $0.date), rate: $0.basalRate)
        }

        var steps: [BasalStep] = []
        let sortedBasal = vc.basalData.sorted { $0.date < $1.date }
        for i in 0 ..< sortedBasal.count {
            let start = sortedBasal[i].date
            let end = i + 1 < sortedBasal.count
                ? sortedBasal[i + 1].date
                : dateTimeUtils.getNowTimeIntervalUTC()
            guard end > start else { continue }
            steps.append(BasalStep(
                start: Date(timeIntervalSince1970: start),
                end: Date(timeIntervalSince1970: end),
                rate: sortedBasal[i].basalRate
            ))
        }
        basal = steps
        let computedMaxBasal = steps.map(\.rate).max() ?? 0
        maxBasal = max(computedMaxBasal, Storage.shared.minBasalScale.value)

        let yTop = maxBG - 5
        let yBottom = maxBG - 25
        overrides = vc.overrideGraphData.map {
            BandRect(
                start: Date(timeIntervalSince1970: $0.date),
                end: Date(timeIntervalSince1970: $0.endDate),
                yBottom: yBottom,
                yTop: yTop,
                pillText: "Override x\(String(format: "%.2f", $0.insulNeedsScaleFactor))"
            )
        }
        tempTargets = vc.tempTargetGraphData.map {
            let target = $0.correctionRange.first.map { String($0) } ?? ""
            return BandRect(
                start: Date(timeIntervalSince1970: $0.date),
                end: Date(timeIntervalSince1970: $0.endDate),
                yBottom: yBottom,
                yTop: yTop,
                pillText: "Temp Target\n\(Localizer.toDisplayUnits(target))"
            )
        }

        let currentNow = Date(timeIntervalSince1970: dateTimeUtils.getNowTimeIntervalUTC())
        now = currentNow
        let hoursBack = TimeInterval(Storage.shared.downloadDays.value * 24 * 3600)
        domainStart = currentNow.addingTimeInterval(-hoursBack)
        domainEnd = currentNow.addingTimeInterval(3 * 3600)

        // 30/90 min lookback markers
        thirtyMinMark = currentNow.addingTimeInterval(-1800)
        ninetyMinMark = currentNow.addingTimeInterval(-5400)

        // DIA markers: every hour going back for 6 hours
        var dia: [Date] = []
        for i in 1 ... 6 {
            dia.append(currentNow.addingTimeInterval(TimeInterval(-i * 3600)))
        }
        diaMarkers = dia

        // Midnight markers: every local midnight within domain
        var midnights: [Date] = []
        let calendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            if Storage.shared.graphTimeZoneEnabled.value,
               let tz = TimeZone(identifier: Storage.shared.graphTimeZoneIdentifier.value)
            {
                cal.timeZone = tz
            }
            return cal
        }()
        var cursor = calendar.startOfDay(for: domainStart)
        while cursor <= domainEnd {
            if cursor >= domainStart {
                midnights.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        midnightMarkers = midnights

        generation &+= 1
    }
}
