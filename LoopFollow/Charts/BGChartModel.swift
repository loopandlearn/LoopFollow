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

    /// Maps the persisted zoom scale (24 h divided by the scale factor) to a
    /// visible-window length.
    static func visibleSeconds(forScale scale: Double) -> TimeInterval {
        guard scale > 0 else { return 6 * 3600 }
        return min(max(24 * 3600 / scale, 15 * 60), 24 * 3600)
    }

    /// Persists the current zoom back into the stored scale representation.
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
        /// Where the symbol is drawn. Equals `date` unless `spread` nudged it
        /// left to keep a crowded run of treatments from stacking up.
        var drawnDate: Date
        var id: Double { date.timeIntervalSince1970 }

        init(date: Date, value: Double, sgv: Double, label: String, pillText: String) {
            self.date = date
            self.value = value
            self.sgv = sgv
            self.label = label
            self.pillText = pillText
            drawnDate = date
        }
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
        let label: String
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
    @Published var smallGraphTreatments: Bool = true

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

    /// Formatter for the time line at the bottom of every selection pill.
    /// Recreated on each rebuild so 12/24-hour and graph-time-zone settings apply.
    private var pillTimeFormatter = BGChartModel.makePillTimeFormatter()

    private static func makePillTimeFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate(dateTimeUtils.is24Hour() ? "HH:mm" : "hh:mm")
        if Storage.shared.graphTimeZoneEnabled.value,
           let tz = TimeZone(identifier: Storage.shared.graphTimeZoneIdentifier.value)
        {
            df.timeZone = tz
        }
        return df
    }

    /// The pill's time line for a given point in time.
    func pillTimeString(for date: Date) -> String {
        pillTimeFormatter.string(from: date)
    }

    /// Nightscout remote-command error notes embed a JSON payload after
    /// the human-readable message ("Error text {\"bolus-entry\": 1.5, ...}").
    /// Returns the message plus a compact summary of the payload, or nil when
    /// the note contains no JSON.
    private static func extractMessage(from note: String) -> String? {
        guard let jsonStartIndex = note.range(of: "{\"")?.lowerBound else {
            return nil
        }

        let errorMessage = String(note[..<jsonStartIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var actionContext = ""
        if let jsonData = String(note[jsonStartIndex...]).data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        {
            var actionParts: [String] = []
            if let bolusAmount = json["bolus-entry"] as? Double {
                actionParts.append("Bolus: \(bolusAmount) U")
            }
            if let carbsAmount = json["carbs-entry"] as? Double {
                actionParts.append("Carbs: \(carbsAmount) g")
            }
            if let absorptionTime = json["absorption-time"] as? Double {
                actionParts.append("Absorption: \(absorptionTime) hrs")
            }
            if let otp = json["otp"] as? String {
                actionParts.append("OTP: \(otp)")
            }
            if let enteredBy = json["entered-by"] as? String {
                actionParts.append("From: \(enteredBy)")
            }
            if !actionParts.isEmpty {
                actionContext = " [" + actionParts.joined(separator: ", ") + "]"
            }
        }

        let finalMessage = errorMessage + actionContext
        return finalMessage.isEmpty ? nil : finalMessage
    }

    private func colorFor(_ sgv: Int, thresholds: (low: Double, high: Double)) -> Color {
        if Double(sgv) >= thresholds.high {
            return .yellow
        } else if Double(sgv) <= thresholds.low {
            return .red
        } else {
            return .green
        }
    }

    /// Groups consecutive same-colored readings into line runs (see BGRun).
    /// The segment between two points takes the color of the earlier point.
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

    /// Minimum drawn spacing between two treatments of the same population, and
    /// the furthest a treatment may be moved from its true time to reach it.
    /// Boluses and SMBs share a y-anchor and symbol footprint, so they are
    /// decluttered as one population; carbs carry a wider "30 3h" label, so
    /// they need — and are allowed — more room.
    private enum Spread {
        static let bolusGap: TimeInterval = 240
        static let bolusShift: TimeInterval = 240
        static let carbGap: TimeInterval = 250
        static let carbShift: TimeInterval = 250
    }

    /// Nudges crowded treatments left so their symbols don't stack. The newest
    /// point in a run keeps its true time and earlier ones give way, never by
    /// more than `maxShift` — so a treatment is at most `maxShift` from where it
    /// really happened, and an isolated one never moves at all.
    private static func spread(_ points: [TreatmentPoint], minGap: TimeInterval, maxShift: TimeInterval) -> [TreatmentPoint] {
        var out = points.sorted { $0.date < $1.date }
        spreadSorted(&out, minGap: minGap, maxShift: maxShift)
        return out
    }

    /// Spreads two treatment kinds as a single population — a bolus dot and an
    /// SMB triangle drawn at the same minute overlap just like two dots would —
    /// then hands each kind back its own points.
    private static func spreadTogether(_ first: [TreatmentPoint], _ second: [TreatmentPoint], minGap: TimeInterval, maxShift: TimeInterval) -> ([TreatmentPoint], [TreatmentPoint]) {
        let tagged = (first.map { (isFirst: true, point: $0) } + second.map { (isFirst: false, point: $0) })
            .sorted { $0.point.date < $1.point.date }
        var points = tagged.map(\.point)
        spreadSorted(&points, minGap: minGap, maxShift: maxShift)
        var outFirst: [TreatmentPoint] = []
        var outSecond: [TreatmentPoint] = []
        for (tag, point) in zip(tagged, points) {
            if tag.isFirst {
                outFirst.append(point)
            } else {
                outSecond.append(point)
            }
        }
        return (outFirst, outSecond)
    }

    /// `points` must be sorted ascending by `date`.
    private static func spreadSorted(_ out: inout [TreatmentPoint], minGap: TimeInterval, maxShift: TimeInterval) {
        guard out.count > 1 else { return }

        // Walking left from the newest point, each point yields to its right
        // neighbor until it hits its own left bound (`date - maxShift`).
        var clamped = [Bool](repeating: false, count: out.count)
        for i in stride(from: out.count - 2, through: 0, by: -1) {
            let wanted = out[i + 1].drawnDate.addingTimeInterval(-minGap)
            guard out[i].drawnDate > wanted else { continue }
            let leftBound = out[i].date.addingTimeInterval(-maxShift)
            if wanted <= leftBound {
                out[i].drawnDate = leftBound
                clamped[i] = true
            } else {
                out[i].drawnDate = wanted
            }
        }

        // A chain of clamped points was squeezed against its left bound and may
        // have piled up there (several same-time treatments all land at
        // date - maxShift). Re-space each chain evenly between that bound and
        // the first point to its right that still had room.
        var i = 0
        while i < out.count - 1 {
            guard clamped[i] else {
                i += 1
                continue
            }
            var last = i
            while clamped[last + 1] {
                last += 1
            }
            let anchorIndex = last + 1
            let anchor = out[anchorIndex].drawnDate
            let leftBound = out[i].date.addingTimeInterval(-maxShift)
            let spacing = anchor.timeIntervalSince(leftBound) / Double(anchorIndex - i)
            for k in i ... last {
                let ideal = anchor.addingTimeInterval(-spacing * Double(anchorIndex - k))
                let boundK = out[k].date.addingTimeInterval(-maxShift)
                out[k].drawnDate = min(max(ideal, boundK), out[k].date)
            }
            i = anchorIndex + 1
        }
    }

    /// Schedules a rebuild, coalescing bursts: a refresh cycle calls a dozen
    /// update*Graph() entry points back-to-back, and rebuilding once per
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

        pillTimeFormatter = Self.makePillTimeFormatter()

        let maxBGValue = Double(vc.calculateMaxBgGraphValue())
        maxBG = max(maxBGValue, Storage.shared.minBGScale.value)

        // Same thresholds the stats and main header use: fixed 70–180 / 70–140
        // for the TIR/TITR range modes, the user's lines for custom mode.
        let thresholds = UnitSettingsStore.shared.effectiveThresholds()
        lowLine = thresholds.low
        highLine = thresholds.high

        showLines = Storage.shared.showLines.value
        showDots = Storage.shared.showDots.value
        showDIA = Storage.shared.showDIALines.value
        show30Min = Storage.shared.show30MinLine.value
        show90Min = Storage.shared.show90MinLine.value
        showMidnight = Storage.shared.showMidnightLines.value
        smallGraphTreatments = Storage.shared.smallGraphTreatments.value

        let isLoop = Storage.shared.device.value == "Loop"
        overrideColor = isLoop ? .green : .purple
        tempTargetColor = isLoop ? .purple : .green

        // Clamp plotted BG to the display range (see #600); color is still
        // keyed off the true reading.
        let minDisplay = globalVariables.minDisplayGlucose
        let maxDisplay = globalVariables.maxDisplayGlucose
        func clampSgv(_ sgv: Int) -> Double { Double(min(max(sgv, minDisplay), maxDisplay)) }

        bg = vc.bgData.map { BGPoint(date: Date(timeIntervalSince1970: $0.date), value: clampSgv($0.sgv), color: colorFor($0.sgv, thresholds: thresholds)) }
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

        let bolusPoints = vc.bolusData.map {
            let dose = self.formatDose($0.value)
            return TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: $0.value,
                sgv: Double($0.sgv),
                label: dose,
                pillText: "Bolus\n\(dose)U\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
        }
        carbs = Self.spread(vc.carbData.map {
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
                pillText: "Carbs\n\(grams)g\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
        }, minGap: Spread.carbGap, maxShift: Spread.carbShift)
        let smbPoints = vc.smbData.map {
            let dose = self.formatDose($0.value)
            return TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: $0.value,
                sgv: Double($0.sgv),
                label: dose,
                pillText: "SMB\n\(dose)U\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
        }
        (boluses, smbs) = Self.spreadTogether(bolusPoints, smbPoints, minGap: Spread.bolusGap, maxShift: Spread.bolusShift)
        bgChecks = vc.bgCheckData.map {
            TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: Double($0.sgv),
                sgv: Double($0.sgv),
                label: "",
                pillText: "BG Check\n\(Localizer.toDisplayUnits(String($0.sgv)))\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
        }
        suspends = vc.suspendGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: "", pillText: "Suspend\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))")
        }
        resumes = vc.resumeGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: "", pillText: "Resume\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))")
        }
        sensorStarts = vc.sensorStartGraphData.map {
            TreatmentPoint(date: Date(timeIntervalSince1970: $0.date), value: Double($0.sgv), sgv: Double($0.sgv), label: "", pillText: "Sensor Start\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))")
        }
        notes = vc.noteGraphData.map {
            TreatmentPoint(
                date: Date(timeIntervalSince1970: $0.date),
                value: Double($0.sgv),
                sgv: Double($0.sgv),
                label: $0.note,
                pillText: "\(Self.extractMessage(from: $0.note) ?? $0.note)\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
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
            let overrideName = $0.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = overrideName.isEmpty ? "Override" : overrideName
            return BandRect(
                start: Date(timeIntervalSince1970: $0.date),
                end: Date(timeIntervalSince1970: $0.endDate),
                yBottom: yBottom,
                yTop: yTop,
                label: displayName,
                pillText: "Override\n\(displayName)\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
        }
        tempTargets = vc.tempTargetGraphData.map {
            let target = $0.correctionRange.first.map { String($0) } ?? ""
            // Temp targets render at the BG level they target (±5 mg/dL);
            // only overrides live in the top strip.
            let yCenter = Double($0.correctionRange.first ?? 0)
            return BandRect(
                start: Date(timeIntervalSince1970: $0.date),
                end: Date(timeIntervalSince1970: $0.endDate),
                yBottom: yCenter - 5,
                yTop: yCenter + 5,
                label: "Temp Target",
                pillText: "Temp Target\n\(Localizer.toDisplayUnits(target))\n\(pillTimeString(for: Date(timeIntervalSince1970: $0.date)))"
            )
        }

        let currentNow = Date(timeIntervalSince1970: dateTimeUtils.getNowTimeIntervalUTC())
        now = currentNow
        let hoursBack = TimeInterval(Storage.shared.downloadDays.value * 24 * 3600)
        domainStart = currentNow.addingTimeInterval(-hoursBack)
        // Everything drawn in the future (predictions, cone, override/temp-target
        // bands) is bounded by the "Hours of Prediction" setting, so the scale
        // domain ends there too. The 15-minute floor keeps room for follow
        // mode's right-side padding when predictions are set to 0 (and matches
        // the floor Overrides.swift uses for future bands).
        let hoursForward = max(Storage.shared.predictionToLoad.value, 0.25) * 3600
        domainEnd = currentNow.addingTimeInterval(hoursForward)

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
