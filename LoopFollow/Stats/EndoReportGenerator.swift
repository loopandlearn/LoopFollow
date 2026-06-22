// LoopFollow
// EndoReportGenerator.swift

import PDFKit
import UIKit

// MARK: - Generator

enum EndoReportGenerator {
    enum ReportError: LocalizedError {
        case noData
        var errorDescription: String? { "No CGM data available for the selected date range." }
    }

    static func generate(config: EndoReportConfig, dataService: StatsDataService) throws -> URL {
        let bgData = dataService.getBGData()
        guard !bgData.isEmpty else { throw ReportError.noData }

        // Use the existing ViewModels for calculations
        let agpVM = AGPViewModel(dataService: dataService)
        agpVM.calculateAGP()

        let stats = ReportStats(bgData: bgData, dataService: dataService)
        let patterns = TimePatterns(bgData: bgData)
        let boluses = dataService.getBolusData()
        let smbs = dataService.getSMBData()
        let carbs = dataService.getCarbData()
        let basals = dataService.getBasalData()
        let basalProfile = dataService.getBasalProfile() // Get basal profile here
        let simpleVM = SimpleStatsViewModel(dataService: dataService)
        simpleVM.calculateStats()

        let pageRect = CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EndoReport_\(Int(Date().timeIntervalSince1970)).pdf")

        let dailyData = groupByDay(bgData: bgData, boluses: boluses, smbs: smbs, basals: basals, carbs: carbs)
            .sorted { $0.key > $1.key }

        let data = renderer.pdfData { ctx in
            // Page 1 — Summary
            ctx.beginPage()
            drawSummaryPage(ctx: ctx.cgContext, r: pageRect, cfg: config,
                            bgData: bgData, agpData: agpVM.agpData,
                            stats: stats, patterns: patterns,
                            boluses: boluses, smbs: smbs, carbs: carbs,
                            simpleVM: simpleVM)

            // Pages 2+ — Daily breakdowns
            if config.includeDailyBreakdown && !dailyData.isEmpty {
                let rowH: CGFloat = 88
                let rowGap: CGFloat = 6
                let topY: CGFloat = 52
                let botY: CGFloat = 762
                let usable = botY - topY
                let perPage = Int((usable + rowGap) / (rowH + rowGap))
                let pages = Int(ceil(Double(dailyData.count) / Double(perPage)))

                for p in 0 ..< pages {
                    ctx.beginPage()
                    let pageNum = p + 2
                    let headerY = drawDailyPageHeader(ctx: ctx.cgContext, r: pageRect,
                                                      cfg: config, page: pageNum,
                                                      totalPages: pages + 1)
                    let slice = Array(dailyData[p * perPage ..< min((p + 1) * perPage, dailyData.count)])
                    var y = headerY + 8
                    for (day, dayData) in slice {
                        drawDayRow(ctx: ctx.cgContext, x: 28, y: y,
                                   w: pageRect.width - 56, h: rowH,
                                   day: day, dayData: dayData, cfg: config, basalProfile: basalProfile)
                        y += rowH + rowGap
                    }
                    drawFooter(ctx: ctx.cgContext, r: pageRect, cfg: config,
                               stats: stats, page: pageNum)
                }
            }
        }
        try data.write(to: url)
        return url
    }

    // MARK: - Data models

    struct ReportStats {
        let avg, stdDev, cv, eA1C, minBG, maxBG, sensorPct, tir, tightTIR, days: Double
        let veryLow, low, inRange, high, veryHigh: Double
        let readingCount: Int

        init(bgData: [ShareGlucoseData], dataService: StatsDataService) {
            let v = bgData.map { Double($0.sgv) }; let n = Double(v.count)
            let m = v.reduce(0,+) / n
            let variance = v.map { ($0 - m) * ($0 - m) }.reduce(0,+) / n

            avg = m; stdDev = sqrt(variance); cv = stdDev / m * 100; eA1C = (m + 46.7) / 28.7
            minBG = v.min() ?? 0; maxBG = v.max() ?? 0; readingCount = v.count
            days = Swift.max(dataService.endDate.timeIntervalSince1970 - dataService.startDate.timeIntervalSince1970, 86400) / 86400
            sensorPct = Swift.min(Double(v.count) / (days * 288) * 100, 100)

            // Calculate TIR Buckets
            let vLowCount = Double(v.filter { $0 < 54 }.count)
            let lowCount = Double(v.filter { $0 >= 54 && $0 < 70 }.count)
            let inRangeCount = Double(v.filter { $0 >= 70 && $0 <= 180 }.count)
            let highCount = Double(v.filter { $0 > 180 && $0 <= 250 }.count)
            let vHighCount = Double(v.filter { $0 > 250 }.count)

            veryLow = (vLowCount / n) * 100
            low = (lowCount / n) * 100
            inRange = (inRangeCount / n) * 100
            high = (highCount / n) * 100
            veryHigh = (vHighCount / n) * 100
            tir = inRange
            tightTIR = Double(v.filter { $0 >= 70 && $0 <= 140 }.count) / n * 100
        }
    }

    struct TimePatterns {
        struct Period { let label: String; let avg: Double; let count: Int }
        let night, earlyAM, morning, afternoon, evening, late: Period
        init(bgData: [ShareGlucoseData]) {
            func p(_ l: String, _ s: Int, _ e: Int) -> Period {
                let cal = dateTimeUtils.displayCalendar()
                let r = bgData.filter { let h = cal.component(.hour, from: Date(timeIntervalSince1970: $0.date)); return h >= s && h < e }
                return Period(label: l, avg: r.isEmpty ? 0 : r.map { Double($0.sgv) }.reduce(0,+) / Double(r.count), count: r.count)
            }
            night = p("Night", 0, 3); earlyAM = p("Early AM", 3, 6); morning = p("Morning", 6, 12)
            afternoon = p("Afternoon", 12, 17); evening = p("Evening", 17, 21); late = p("Late", 21, 24)
        }
    }

    struct DayData {
        let bg: [ShareGlucoseData]
        let bolus: [MainViewController.bolusGraphStruct]
        let smb: [MainViewController.bolusGraphStruct]
        let basal: [MainViewController.basalGraphStruct]
        let carbs: [MainViewController.carbGraphStruct]
    }

    private static func groupByDay(
        bgData: [ShareGlucoseData],
        boluses: [MainViewController.bolusGraphStruct],
        smbs: [MainViewController.bolusGraphStruct],
        basals: [MainViewController.basalGraphStruct],
        carbs: [MainViewController.carbGraphStruct]
    ) -> [String: DayData] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var bg: [String: [ShareGlucoseData]] = [:]
        var bo: [String: [MainViewController.bolusGraphStruct]] = [:]
        var sm: [String: [MainViewController.bolusGraphStruct]] = [:]
        var ba: [String: [MainViewController.basalGraphStruct]] = [:]
        var ca: [String: [MainViewController.carbGraphStruct]] = [:]
        for r in bgData {
            let k = df.string(from: Date(timeIntervalSince1970: r.date)); bg[k, default: []].append(r)
        }
        for r in boluses {
            let k = df.string(from: Date(timeIntervalSince1970: r.date)); bo[k, default: []].append(r)
        }
        for r in smbs {
            let k = df.string(from: Date(timeIntervalSince1970: r.date)); sm[k, default: []].append(r)
        }
        for r in basals {
            let k = df.string(from: Date(timeIntervalSince1970: r.date)); ba[k, default: []].append(r)
        }
        for r in carbs {
            let k = df.string(from: Date(timeIntervalSince1970: r.date)); ca[k, default: []].append(r)
        }
        var result: [String: DayData] = [:]
        for k in bg.keys {
            result[k] = DayData(bg: bg[k]!, bolus: bo[k] ?? [], smb: sm[k] ?? [], basal: ba[k] ?? [], carbs: ca[k] ?? [])
        }
        return result
    }

    // MARK: - Colors / fonts

    private static func accent(_ cfg: EndoReportConfig) -> UIColor { cfg.accentColor }
    private static func accentDark(_ cfg: EndoReportConfig) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        cfg.accentColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: b * 0.72, alpha: a)
    }

    private static let C_INK = UIColor(red: 0.133, green: 0.157, blue: 0.192, alpha: 1)
    private static let C_SLATE = UIColor(red: 0.400, green: 0.440, blue: 0.490, alpha: 1)
    private static let C_CLOUD = UIColor(red: 0.960, green: 0.963, blue: 0.970, alpha: 1)
    private static let C_BORDER = UIColor(red: 0.870, green: 0.885, blue: 0.905, alpha: 1)
    private static let C_WHITE = UIColor.white
    private static let C_VLOW = UIColor(red: 0.820, green: 0.180, blue: 0.180, alpha: 1)
    private static let C_LOW = UIColor(red: 0.929, green: 0.490, blue: 0.188, alpha: 1)
    private static let C_IN = UIColor(red: 0.200, green: 0.670, blue: 0.470, alpha: 1)
    private static let C_HIGH = UIColor(red: 0.910, green: 0.740, blue: 0.220, alpha: 1)
    private static let C_VHIGH = UIColor(red: 0.800, green: 0.340, blue: 0.340, alpha: 1)
    private static let C_BOLUS = UIColor(red: 0.380, green: 0.220, blue: 0.780, alpha: 0.85)
    private static let C_SMB = UIColor(red: 0.800, green: 0.200, blue: 0.600, alpha: 0.75)
    private static let C_CARB = UIColor(red: 0.150, green: 0.600, blue: 0.150, alpha: 1.0)
    private static let C_BASAL = UIColor(red: 0.102, green: 0.451, blue: 0.933, alpha: 0.65)

    // Shared TIR palette used in both the summary TIR card and daily BG rendering.
    private static let C_TIR_VHIGH = UIColor(red: 0.78, green: 0.22, blue: 0.20, alpha: 1)
    private static let C_TIR_HIGH = UIColor(red: 0.88, green: 0.75, blue: 0.29, alpha: 1)
    private static let C_TIR_IN = UIColor(red: 0.35, green: 0.68, blue: 0.50, alpha: 1)
    private static let C_TIR_LOW = UIColor(red: 0.88, green: 0.51, blue: 0.24, alpha: 1)
    private static let C_TIR_VLOW = UIColor(red: 0.78, green: 0.22, blue: 0.20, alpha: 1)

    private static func bgColor(_ bg: Double) -> UIColor {
        switch bg {
        case ..<54: return C_TIR_VLOW
        case ..<70: return C_TIR_LOW
        case ...180: return C_TIR_IN
        case ...250: return C_TIR_HIGH
        default: return C_TIR_VHIGH
        }
    }

    // MARK: - Page 1: Summary

    private static func drawSummaryPage(
        ctx: CGContext, r: CGRect, cfg: EndoReportConfig,
        bgData _: [ShareGlucoseData], agpData: [AGPDataPoint],
        stats: ReportStats, patterns: TimePatterns,
        boluses: [MainViewController.bolusGraphStruct],
        smbs: [MainViewController.bolusGraphStruct],
        carbs: [MainViewController.carbGraphStruct],
        simpleVM: SimpleStatsViewModel
    ) {
        let m: CGFloat = 24
        var y = drawHero(ctx: ctx, r: r, cfg: cfg, stats: stats)

        if cfg.includeGlucoseSummary {
            y = sectionHdr("GLUCOSE SUMMARY", y: y + 2, m: m, w: r.width, cfg: cfg, ctx: ctx)

            let gridW: CGFloat = r.width - m * 2 - 158
            let cw = gridW / 2 - 3; let ch: CGFloat = 36
            let cards: [(String, String, Bool)] = [
                ("TIME IN RANGE (>70%)", String(format: "%.0f%%", stats.tir), true),
                ("GMI (TARGET <7%)", String(format: "%.1f%%", stats.eA1C), false),
                ("AVERAGE", cfg.fmtBG(stats.avg) + " \(cfg.units)", false),
                ("STD DEVIATION", cfg.fmtBG(stats.stdDev), false),
                ("CV (TARGET <36%)", String(format: "%.0f%%", stats.cv), false),
                ("READINGS", "\(stats.readingCount)", false),
            ]
            let gy = y + 1
            for (i, c) in cards.enumerated() {
                statCard(c.0, val: c.1, x: m + CGFloat(i % 2) * (cw + 6), y: gy + CGFloat(i / 2) * (ch + 4),
                         w: cw, h: ch, accent: c.2, cfg: cfg, ctx: ctx)
            }
            drawTIRBar(stats: stats, x: m + gridW + 10, y: y + 1,
                       w: 148, h: ch * 3 + 7, cfg: cfg, ctx: ctx)
            y = gy + CGFloat(3) * (ch + 4) + 1

            y = timeStrip(patterns: patterns, cfg: cfg, y: y + 1, m: m, w: r.width, ctx: ctx)
        }

        if cfg.includeInsulin && (!boluses.isEmpty || !smbs.isEmpty) {
            y = sectionHdr("INSULIN DELIVERY", y: y + 2, m: m, w: r.width, cfg: cfg, ctx: ctx)
            y = insulinSection(boluses: boluses, smbs: smbs, simpleVM: simpleVM,
                               stats: stats, cfg: cfg, y: y + 1, m: m, w: r.width, ctx: ctx)
        }

        if cfg.includeNutrition && !carbs.isEmpty {
            y = sectionHdr("NUTRITION & MEALS", y: y + 2, m: m, w: r.width, cfg: cfg, ctx: ctx)
            y = nutritionSection(carbs: carbs, stats: stats, cfg: cfg, y: y + 1, m: m, w: r.width, ctx: ctx)
        }

        let hasDevice = cfg.includeDevices && (!cfg.pumpDevice.isEmpty || !cfg.cgmDevice.isEmpty || !cfg.insulinType.isEmpty)
        let hasSettings = cfg.includeTherapySettings && (!cfg.carbRatio.isEmpty || !cfg.isf.isEmpty || !cfg.basalRate.isEmpty || !cfg.targetGlucose.isEmpty)

        if hasDevice || hasSettings {
            y = sectionHdr("SYSTEM & THERAPY SETTINGS", y: y + 2, m: m, w: r.width, cfg: cfg, ctx: ctx)
            var gridItems: [(String, String)] = []
            if hasDevice {
                if !cfg.pumpDevice.isEmpty { gridItems.append(("Pump", cfg.pumpDevice)) }
                if !cfg.cgmDevice.isEmpty { gridItems.append(("CGM", cfg.cgmDevice)) }
                if !cfg.insulinType.isEmpty { gridItems.append(("Insulin", cfg.insulinType)) }
            }
            if hasSettings {
                if !cfg.carbRatio.isEmpty { gridItems.append(("CR", cfg.carbRatio)) }
                if !cfg.isf.isEmpty { gridItems.append(("ISF", cfg.isf)) }
                if !cfg.basalRate.isEmpty { gridItems.append(("Basal", formatBasalRateForDisplay(cfg.basalRate))) }
                if !cfg.targetGlucose.isEmpty { gridItems.append(("Target", cfg.targetGlucose)) }
            }
            y = drawSettingsGrid(gridItems, x: m, y: y + 1, width: r.width - m * 2, cfg: cfg, ctx: ctx)
        }

        if !cfg.notes.isEmpty {
            y = drawNotesSection(cfg.notes, x: m, y: y + 2, width: r.width - m * 2, cfg: cfg, ctx: ctx)
        }

        if cfg.includeAGP, !agpData.isEmpty {
            let agpAvail = r.height - y - 40
            if agpAvail >= 80 {
                y = sectionHdr("AMBULATORY GLUCOSE PROFILE", y: y + 6, m: m, w: r.width, cfg: cfg, ctx: ctx)
                let agpH = Swift.min(agpAvail - 20, 130)
                drawAGP(agpData: agpData, x: m, y: y + 4, w: r.width - m * 2, h: agpH, cfg: cfg, ctx: ctx)
            }
        }

        drawFooter(ctx: ctx, r: r, cfg: cfg, stats: stats, page: 1)
    }

    // MARK: - Hero header

    @discardableResult
    private static func drawHero(ctx: CGContext, r: CGRect, cfg: EndoReportConfig, stats: ReportStats) -> CGFloat {
        let h: CGFloat = 90; let ac = accent(cfg); let ad = accentDark(cfg)
        ctx.setFillColor(ac.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: h))
        ctx.setFillColor(ad.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: 21))

        let a1: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: C_WHITE.withAlphaComponent(0.8), .kern: 3.0]
        "LOOP FOLLOW".draw(at: CGPoint(x: 26, y: 5), withAttributes: a1)

        let a2: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 21), .foregroundColor: C_WHITE]
        "Endocrinologist Visit Report".draw(at: CGPoint(x: 26, y: 26), withAttributes: a2)

        let a3: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9.5), .foregroundColor: C_WHITE.withAlphaComponent(0.82)]
        "Automated Insulin Delivery Performance Summary".draw(at: CGPoint(x: 26, y: 52), withAttributes: a3)

        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        let ds = "\(df.string(from: cfg.startDate)) — \(df.string(from: cfg.endDate)) (\(Int(stats.days.rounded())) Days)"
        let a4: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: C_WHITE.withAlphaComponent(0.68)]
        ds.draw(at: CGPoint(x: 26, y: 68), withAttributes: a4)

        let a5: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: C_WHITE.withAlphaComponent(0.95)]
        var lines: [String] = []
        if !cfg.patientName.isEmpty { lines.append("Patient: \(cfg.patientName)") }
        if !cfg.providerName.isEmpty { lines.append("Provider: \(cfg.providerName)") }
        if !cfg.dateOfBirth.isEmpty { lines.append("DOB: \(cfg.dateOfBirth)") }
        if !cfg.aidSystem.isEmpty { lines.append("AID: \(cfg.aidSystem)") }
        if !cfg.diagnosisDate.isEmpty { lines.append("Dx: \(cfg.diagnosisDate)") }

        for (i, l) in lines.enumerated() {
            let sz = (l as NSString).size(withAttributes: a5)
            (l as NSString).draw(at: CGPoint(x: r.width - 26 - sz.width, y: 24 + CGFloat(i) * 11.5), withAttributes: a5)
        }
        return h
    }

    // MARK: - Daily page header

    @discardableResult
    private static func drawDailyPageHeader(ctx: CGContext, r: CGRect, cfg: EndoReportConfig,
                                            page: Int, totalPages: Int) -> CGFloat
    {
        let h: CGFloat = 40; let ac = accent(cfg)
        ctx.setFillColor(ac.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: h))
        let a1: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: C_WHITE]
        "Daily Glucose Breakdown".draw(at: CGPoint(x: 28, y: 11), withAttributes: a1)
        let sub = "Newest to Oldest  •  Page \(page) of \(totalPages)"
        let a2: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: C_WHITE.withAlphaComponent(0.75)]
        let sz = (sub as NSString).size(withAttributes: a2)
        (sub as NSString).draw(at: CGPoint(x: r.width - 28 - sz.width, y: 14), withAttributes: a2)
        return h
    }

    // MARK: - Section header

    @discardableResult
    private static func sectionHdr(_ title: String, y: CGFloat, m: CGFloat, w: CGFloat,
                                   cfg: EndoReportConfig, ctx: CGContext) -> CGFloat
    {
        ctx.setFillColor(accent(cfg).cgColor)
        ctx.fill(CGRect(x: m, y: y, width: 3, height: 14))
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: accent(cfg), .kern: 0.6]
        (title as NSString).draw(at: CGPoint(x: m + 8, y: y), withAttributes: a)
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: m, y: y + 15)); ctx.addLine(to: CGPoint(x: w - m, y: y + 15)); ctx.strokePath()
        return y + 16
    }

    // MARK: - Stat card

    private static func statCard(_ label: String, val: String, x: CGFloat, y: CGFloat,
                                 w: CGFloat, h: CGFloat, accent ac: Bool,
                                 cfg: EndoReportConfig, ctx: CGContext)
    {
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r)
        if ac {
            ctx.setFillColor(accent(cfg).withAlphaComponent(0.07).cgColor); ctx.fill(r)
            ctx.setFillColor(accent(cfg).cgColor); ctx.fill(CGRect(x: x, y: y, width: 3, height: h))
        }
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r)
        let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.5]
        let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: ac ? accent(cfg) : C_INK]
        (label as NSString).draw(at: CGPoint(x: x + 8, y: y + 4), withAttributes: la)
        (val as NSString).draw(at: CGPoint(x: x + 8, y: y + 14), withAttributes: va)
    }

    // MARK: - TIR vertical bar

    private static func drawTIRBar(stats: ReportStats,
                                   x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                   cfg _: EndoReportConfig, ctx: CGContext)
    {
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r)
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r)

        let ta: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: C_SLATE]
        "Time in Range".draw(at: CGPoint(x: x + 8, y: y + 6), withAttributes: ta)

        let targetLine1Y = y + h - 24
        let targetLine2Y = y + h - 12

        // Reserve explicit space above target lines so the five legend labels stay comfortably separated.
        let bx = x + 10
        let bw: CGFloat = 16
        let by = y + 22
        let legendTop = by + 1
        let legendBottom = targetLine1Y - 13
        let bh = max(legendBottom - by, 20)

        let segs: [(Double, UIColor, String)] = [
            (stats.veryHigh, C_TIR_VHIGH, "Very High"), (stats.high, C_TIR_HIGH, "High"),
            (stats.inRange, C_TIR_IN, "In Range"), (stats.low, C_TIR_LOW, "Low"),
            (stats.veryLow, C_TIR_VLOW, "Very Low"),
        ]
        var sy = by

        for (pct, clr, _) in segs {
            let sh = CGFloat(pct / 100) * bh
            if sh > 0 {
                ctx.setFillColor(clr.cgColor)
                ctx.fill(CGRect(x: bx, y: sy, width: bw, height: sh))
            }
            sy += sh
        }

        // Always show all 5 zones regardless of percentage value.
        let legendX = bx + bw + 8
        let legendSpacing = max((legendBottom - legendTop) / CGFloat(segs.count - 1), 8)
        for (index, (pct, clr, label)) in segs.enumerated() {
            let ps = String(format: "%.0f%%", pct)
            let isTarget = (label == "In Range")
            let pa: [NSAttributedString.Key: Any] = [
                .font: isTarget ? UIFont.boldSystemFont(ofSize: 7.5) : UIFont.systemFont(ofSize: 7),
                .foregroundColor: isTarget ? clr : C_SLATE,
            ]
            let textStr = "\(label) \(ps)"
            let textY = legendTop + CGFloat(index) * legendSpacing

            ctx.setFillColor(clr.cgColor)
            ctx.fill(CGRect(x: legendX, y: textY + 2, width: 6, height: 6))
            (textStr as NSString).draw(at: CGPoint(x: legendX + 9, y: textY), withAttributes: pa)
        }

        let na: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
        "Target: 70-180".draw(at: CGPoint(x: x + 5, y: targetLine1Y), withAttributes: na)
        let tightRangeText = String(format: "Tight Range 70-140: %.0f%%", stats.tightTIR)
        tightRangeText.draw(at: CGPoint(x: x + 5, y: targetLine2Y), withAttributes: na)
    }

    // MARK: - Time-of-day strip

    @discardableResult
    private static func timeStrip(patterns: TimePatterns, cfg: EndoReportConfig,
                                  y: CGFloat, m: CGFloat, w: CGFloat, ctx: CGContext) -> CGFloat
    {
        let ha: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: C_INK]
        "Glucose by Time of Day (\(cfg.units))".draw(at: CGPoint(x: m, y: y), withAttributes: ha)

        let periods = [patterns.night, patterns.earlyAM, patterns.morning,
                       patterns.afternoon, patterns.evening, patterns.late]
        // Time range labels matching the GlycemicPatterns init hours
        let timeRanges = ["00:00–03:00", "03:00–06:00", "06:00–12:00",
                          "12:00–17:00", "17:00–21:00", "21:00–24:00"]

        let cw = (w - m * 2) / CGFloat(periods.count)
        let ch: CGFloat = 48
        let cy = y + 11

        for (i, p) in periods.enumerated() {
            let cx = m + CGFloat(i) * cw
            let cardWidth = cw - 2
            let rr = CGRect(x: cx, y: cy, width: cardWidth, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(rr)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(rr)

            let timeRange = timeRanges[i]
            let topA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
            let bottomA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: C_SLATE]

            let disp = p.count > 0 ? cfg.fmtBG(p.avg) : "—"
            let vc: UIColor = p.count > 0
                ? (p.avg < 70 ? C_LOW : p.avg < 140 ? accent(cfg) : p.avg < 180 ? C_INK : C_HIGH)
                : C_SLATE
            let valueA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: vc]

            let topSize = (timeRange as NSString).size(withAttributes: topA)
            let valueSize = (disp as NSString).size(withAttributes: valueA)
            let bottomSize = (p.label as NSString).size(withAttributes: bottomA)

            let topToValueGap: CGFloat = 3
            let valueToBottomGap: CGFloat = 2
            let stackHeight = topSize.height + topToValueGap + valueSize.height + valueToBottomGap + bottomSize.height
            let startY = cy + (ch - stackHeight) / 2

            let topX = cx + (cardWidth - topSize.width) / 2
            let valueX = cx + (cardWidth - valueSize.width) / 2
            let bottomX = cx + (cardWidth - bottomSize.width) / 2

            (timeRange as NSString).draw(at: CGPoint(x: topX, y: startY), withAttributes: topA)
            (disp as NSString).draw(at: CGPoint(x: valueX, y: startY + topSize.height + topToValueGap), withAttributes: valueA)
            (p.label as NSString).draw(at: CGPoint(x: bottomX, y: startY + topSize.height + topToValueGap + valueSize.height + valueToBottomGap), withAttributes: bottomA)
        }
        return cy + ch + 2
    }

    // MARK: - Insulin section

    @discardableResult
    private static func insulinSection(boluses: [MainViewController.bolusGraphStruct],
                                       smbs: [MainViewController.bolusGraphStruct],
                                       simpleVM: SimpleStatsViewModel, stats _: ReportStats,
                                       cfg: EndoReportConfig, y: CGFloat, m: CGFloat, w: CGFloat,
                                       ctx: CGContext) -> CGFloat
    {
        let tdd = simpleVM.totalDailyDose ?? 0
        let basalPct = tdd > 0 ? (simpleVM.actualBasal ?? 0) / tdd * 100 : 0
        let bolusPct = tdd > 0 ? (simpleVM.avgBolus ?? 0) / tdd * 100 : 0
        let cards: [(String, String)] = [("AVG TDD", tdd > 0 ? String(format: "%.1fU", tdd) : "—"),
                                         ("BASAL", basalPct > 0 ? String(format: "%.0f%%", basalPct) : "—"),
                                         ("BOLUS", bolusPct > 0 ? String(format: "%.0f%%", bolusPct) : "—")]
        let cw = (w - m * 2) / 3 - 4; let ch: CGFloat = 36
        for (i, c) in cards.enumerated() {
            let cx = m + CGFloat(i) * (cw + 4)
            let r2 = CGRect(x: cx, y: y, width: cw, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r2)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r2)
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.4]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: C_INK]
            (c.0 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 4), withAttributes: la)
            (c.1 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 14), withAttributes: va)
        }
        let ty = y + ch + 2
        let total = (boluses + smbs).map { $0.value }.reduce(0,+)
        let rows: [(String, String)] = [
            ("Manual/Traditional Bolus Events", "\(boluses.count)"),
            ("Automated Microbolus (SMB/Auto-Correction) Events", "\(smbs.count)"),
            ("Total Bolus Insulin (Manual + Automated)", String(format: "%.1f U", total)),
            ("Programmed Basal", simpleVM.programmedBasal != nil ? String(format: "%.2f U/day", simpleVM.programmedBasal!) : "—"),
            ("Actual Basal", simpleVM.actualBasal != nil ? String(format: "%.2f U/day", simpleVM.actualBasal!) : "—"),
        ]
        return metricTable(rows, x: m, y: ty, width: w - m * 2, cfg: cfg, ctx: ctx)
    }

    // MARK: - Nutrition section

    @discardableResult
    private static func nutritionSection(carbs: [MainViewController.carbGraphStruct],
                                         stats: ReportStats, cfg _: EndoReportConfig,
                                         y: CGFloat, m: CGFloat, w: CGFloat, ctx: CGContext) -> CGFloat
    {
        let total = carbs.map { $0.value }.reduce(0,+)
        let cards: [(String, String)] = [
            ("DAILY CARBS", String(format: "%.0fg", total / stats.days)),
            ("MEALS LOGGED", "\(carbs.count)"),
            ("PER MEAL AVG", String(format: "%.0fg", carbs.isEmpty ? 0 : total / Double(carbs.count))),
        ]
        let cw = (w - m * 2) / 3 - 4; let ch: CGFloat = 36
        for (i, c) in cards.enumerated() {
            let cx = m + CGFloat(i) * (cw + 4)
            let r2 = CGRect(x: cx, y: y, width: cw, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r2)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r2)
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.4]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: C_INK]
            (c.0 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 4), withAttributes: la)
            (c.1 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 14), withAttributes: va)
        }
        return y + ch + 2
    }

    // MARK: - Tables

    @discardableResult
    private static func metricTable(_ rows: [(String, String)], x: CGFloat, y: CGFloat,
                                    width: CGFloat, cfg: EndoReportConfig, ctx: CGContext) -> CGFloat
    {
        let tw = width; let hh: CGFloat = 12; let rh: CGFloat = 11; var cy = y
        ctx.setFillColor(accent(cfg).withAlphaComponent(0.10).cgColor)
        ctx.fill(CGRect(x: x, y: cy, width: tw, height: hh))
        let ha: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: accent(cfg), .kern: 0.4]
        "METRIC".draw(at: CGPoint(x: x + 6, y: cy + 1), withAttributes: ha)
        "VALUE".draw(at: CGPoint(x: x + tw * 0.58 + 6, y: cy + 1), withAttributes: ha)
        cy += hh
        for (i, row) in rows.enumerated() {
            ctx.setFillColor((i % 2 == 0 ? C_WHITE : C_CLOUD).cgColor)
            ctx.fill(CGRect(x: x, y: cy, width: tw, height: rh))
            let ka: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7), .foregroundColor: C_INK]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: accent(cfg)]
            (row.0 as NSString).draw(at: CGPoint(x: x + 6, y: cy + 1), withAttributes: ka)
            (row.1 as NSString).draw(at: CGPoint(x: x + tw * 0.58 + 6, y: cy + 1), withAttributes: va)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: x, y: cy + rh)); ctx.addLine(to: CGPoint(x: x + tw, y: cy + rh)); ctx.strokePath()
            cy += rh
        }
        return cy + 1
    }

    // Dynamic settings table to handle multi-line text input neatly
    @discardableResult
    private static func settingsTable(_ rows: [(String, String)], x: CGFloat, y: CGFloat,
                                      width: CGFloat, cfg: EndoReportConfig, ctx: CGContext) -> CGFloat
    {
        let tw = width
        let headerH: CGFloat = 12
        var cy = y

        ctx.setFillColor(accent(cfg).withAlphaComponent(0.10).cgColor)
        ctx.fill(CGRect(x: x, y: cy, width: tw, height: headerH))

        let ha: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: accent(cfg), .kern: 0.4]
        "THERAPY SETTING & VALUES".draw(at: CGPoint(x: x + 6, y: cy + 3), withAttributes: ha)
        cy += headerH

        for (i, row) in rows.enumerated() {
            let lines = row.1.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let rh = 11.0 + CGFloat(lines.count) * 10.5 + 4.0

            ctx.setFillColor((i % 2 == 0 ? C_WHITE : C_CLOUD).cgColor)
            ctx.fill(CGRect(x: x, y: cy, width: tw, height: rh))

            let ka: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: C_SLATE]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: accent(cfg)]

            (row.0 as NSString).draw(at: CGPoint(x: x + 6, y: cy + 3.5), withAttributes: ka)

            var ly = cy + 12.5
            for line in lines {
                (line as NSString).draw(at: CGPoint(x: x + 6, y: ly), withAttributes: va)
                ly += 10.5
            }

            ctx.setStrokeColor(C_BORDER.cgColor)
            ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: x, y: cy + rh))
            ctx.addLine(to: CGPoint(x: x + tw, y: cy + rh))
            ctx.strokePath()

            cy += rh
        }
        return cy + 2
    }

    // MARK: - AGP

    private static func drawAGP(agpData: [AGPDataPoint], x: CGFloat, y: CGFloat,
                                w: CGFloat, h: CGFloat, cfg: EndoReportConfig, ctx: CGContext)
    {
        guard !agpData.isEmpty else { return }
        let lPad: CGFloat = 26; let bPad: CGFloat = 24
        let cw = w - lPad; let ch = h - bPad
        let cx = x + lPad; let cy = y

        ctx.setFillColor(UIColor(white: 0.985, alpha: 1).cgColor)
        ctx.fill(CGRect(x: cx, y: cy, width: cw, height: ch))

        let bgMin: CGFloat = 40; let bgRng: CGFloat = 320
        func gy(_ g: Double) -> CGFloat { cy + ch - (CGFloat(g) - bgMin) / bgRng * ch }
        func tx(_ mins: Int) -> CGFloat { cx + CGFloat(mins) / (24 * 60) * cw }

        ctx.setFillColor(C_IN.withAlphaComponent(0.07).cgColor)
        ctx.fill(CGRect(x: cx, y: gy(180), width: cw, height: gy(70) - gy(180)))

        ctx.setLineDash(phase: 0, lengths: [3, 2])
        for (val, clr) in [(70.0, C_LOW), (180.0, C_HIGH)] {
            ctx.setStrokeColor(clr.withAlphaComponent(0.5).cgColor); ctx.setLineWidth(0.6)
            ctx.move(to: CGPoint(x: cx, y: gy(val))); ctx.addLine(to: CGPoint(x: cx + cw, y: gy(val))); ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        let band = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p95)); i == 0 ? band.move(to: p) : band.addLine(to: p)
        }
        for pt in agpData.reversed() {
            band.addLine(to: CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p5)))
        }
        band.closeSubpath()
        ctx.setFillColor(accent(cfg).withAlphaComponent(0.10).cgColor); ctx.addPath(band); ctx.fillPath()

        let iqr = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p75)); i == 0 ? iqr.move(to: p) : iqr.addLine(to: p)
        }
        for pt in agpData.reversed() {
            iqr.addLine(to: CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p25)))
        }
        iqr.closeSubpath()
        ctx.setFillColor(accent(cfg).withAlphaComponent(0.25).cgColor); ctx.addPath(iqr); ctx.fillPath()

        ctx.setStrokeColor(accent(cfg).cgColor); ctx.setLineWidth(1.6)
        var first = true
        for pt in agpData {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p50)); first ? ctx.move(to: p) : ctx.addLine(to: p); first = false
        }
        ctx.strokePath()

        let axA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
        for bg in [70, 140, 180, 250] {
            let ly = gy(Double(bg)); guard ly >= cy, ly <= cy + ch else { continue }
            let lbl = cfg.isMMOL ? String(format: "%.1f", Double(bg) * 0.0555) : "\(bg)"
            let lsz = (lbl as NSString).size(withAttributes: axA)
            (lbl as NSString).draw(at: CGPoint(x: x + lPad - lsz.width - 3, y: ly - lsz.height / 2), withAttributes: axA)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.25)
            ctx.move(to: CGPoint(x: cx, y: ly)); ctx.addLine(to: CGPoint(x: cx + cw, y: ly)); ctx.strokePath()
        }

        for h2 in stride(from: 0, through: 24, by: 3) {
            let lx = tx(h2 * 60)
            let lbl = String(format: "%02d:00", h2)
            let lsz = (lbl as NSString).size(withAttributes: axA)
            let dx = Swift.max(cx, Swift.min(cx + cw - lsz.width, lx - lsz.width / 2))
            (lbl as NSString).draw(at: CGPoint(x: dx, y: cy + ch + 3), withAttributes: axA)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.25)
            ctx.move(to: CGPoint(x: lx, y: cy)); ctx.addLine(to: CGPoint(x: lx, y: cy + ch)); ctx.strokePath()
        }

        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: cx, y: cy, width: cw, height: ch))

        let lgA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
        let lgItems: [(String, UIColor, Bool)] = [("Median", accent(cfg), false),
                                                  ("25–75th", accent(cfg).withAlphaComponent(0.4), true),
                                                  ("5–95th", accent(cfg).withAlphaComponent(0.18), true)]
        var lgX = cx + cw
        for item in lgItems.reversed() {
            let lsz = (item.0 as NSString).size(withAttributes: lgA)
            lgX -= lsz.width
            (item.0 as NSString).draw(at: CGPoint(x: lgX, y: cy + ch + 11), withAttributes: lgA)
            lgX -= 15
            item.2 ? { ctx.setFillColor(item.1.cgColor); ctx.fill(CGRect(x: lgX, y: cy + ch + 12, width: 12, height: 8)) }()
                : { ctx.setFillColor(item.1.cgColor); ctx.fill(CGRect(x: lgX, y: cy + ch + 15, width: 12, height: 2)) }()
            lgX -= 5
        }
    }

    @discardableResult
    private static func drawSettingsGrid(_ items: [(String, String)], x: CGFloat, y: CGFloat, width: CGFloat, cfg: EndoReportConfig, ctx: CGContext) -> CGFloat {
        let count = CGFloat(items.count)
        guard count > 0 else { return y }
        let spacing: CGFloat = 4
        let cw = (width - (count - 1) * spacing) / count
        var maxH: CGFloat = 0

        for (i, item) in items.enumerated() {
            let cx = x + CGFloat(i) * (cw + spacing)
            let lines = item.1.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let h = 12.0 + CGFloat(lines.count) * 9.5 + 4.0
            maxH = max(maxH, h)

            ctx.setFillColor(C_CLOUD.cgColor)
            ctx.fill(CGRect(x: cx, y: y, width: cw, height: h))
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(CGRect(x: cx, y: y, width: cw, height: h))

            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.8), .foregroundColor: C_SLATE]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: accent(cfg)]

            (item.0 as NSString).draw(at: CGPoint(x: cx + 4, y: y + 2.5), withAttributes: la)
            var ly = y + 10.5
            for line in lines {
                (line as NSString).draw(at: CGPoint(x: cx + 4, y: ly), withAttributes: va)
                ly += 9.5
            }
        }
        return y + maxH + 4
    }

    @discardableResult
    private static func drawNotesSection(_ notes: String, x: CGFloat, y: CGFloat, width: CGFloat, cfg: EndoReportConfig, ctx: CGContext) -> CGFloat {
        let headerY = sectionHdr("NOTES & OBSERVATIONS", y: y, m: x, w: width + x * 2, cfg: cfg, ctx: ctx)
        let font = UIFont.systemFont(ofSize: 8)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: C_INK]

        let textRect = CGRect(x: x + 6, y: headerY + 4, width: width - 12, height: 1000)
        let size = (notes as NSString).boundingRect(with: textRect.size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil).size

        let drawRect = CGRect(x: x + 6, y: headerY + 4, width: width - 12, height: size.height)
        (notes as NSString).draw(in: drawRect, withAttributes: attributes)

        return headerY + 4 + size.height + 4
    }

    // MARK: - Format helpers

    private static func formatBasalRateForDisplay(_ input: String) -> String {
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Helper to extract a double from a string that might contain units or other text
        func extractDouble(_ s: String) -> Double? {
            let cleaned = s.replacingOccurrences(of: ",", with: ".")
                .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .joined()
            return Double(cleaned)
        }

        if input.contains("=") || (input.contains(":") && lines.count > 1) {
            var formatted: [String] = []
            for line in lines {
                let sep = line.contains("=") ? "=" : ":"
                let parts = line.components(separatedBy: sep).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count >= 2, let last = parts.last, let rate = extractDouble(last) {
                    let timeKey = parts.dropLast().joined(separator: sep)
                    formatted.append("\(timeKey) = \(String(format: "%.2f", rate))")
                } else {
                    formatted.append(line)
                }
            }
            return formatted.isEmpty ? input : formatted.joined(separator: "\n")
        }

        if let value = extractDouble(input) {
            return String(format: "%.2f U/hr", value)
        }
        return input
    }

    // MARK: - Basal Profile Helpers

    static func calculateDailyProgrammedBasal(basalProfile: [MainViewController.basalProfileStruct]) -> Double {
        guard !basalProfile.isEmpty else { return 0.0 }

        let sortedProfile = basalProfile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }

        var totalBasal = 0.0
        let secondsInDay = 24 * 60 * 60

        for i in 0 ..< sortedProfile.count {
            let current = sortedProfile[i]
            let currentTime = Double(current.timeAsSeconds)

            let nextTime: Double = (i < sortedProfile.count - 1) ? Double(sortedProfile[i + 1].timeAsSeconds) : Double(secondsInDay)
            let durationHours = (nextTime - currentTime) / 3600.0
            totalBasal += current.value * durationHours
        }

        return totalBasal
    }

    // MARK: - Day row

    private static func drawDayRow(ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                   day: String, dayData: DayData, cfg: EndoReportConfig,
                                   basalProfile: [MainViewController.basalProfileStruct])
    {
        ctx.setFillColor(C_WHITE.cgColor); ctx.fill(CGRect(x: x, y: y, width: w, height: h))
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: x, y: y, width: w, height: h))

        ctx.setFillColor(cfg.accentColor.cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 3, height: h))

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let df2 = DateFormatter(); df2.dateFormat = "EEEE, MMM d, yyyy"
        let date = df.date(from: day) ?? Date()
        let dayLabel = df2.string(from: date)
        let dlA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: C_INK]
        dayLabel.draw(at: CGPoint(x: x + 10, y: y + 5), withAttributes: dlA)

        // Statistics Container on the Right
        let statsW: CGFloat = 115
        let statsX = x + w - statsW
        let boxRect = CGRect(x: statsX, y: y + 1, width: statsW - 1, height: h - 2)
        ctx.setFillColor(C_CLOUD.cgColor)
        ctx.fill(boxRect)

        ctx.setStrokeColor(C_BORDER.cgColor)
        ctx.setLineWidth(0.4)
        ctx.move(to: CGPoint(x: statsX, y: y + 1))
        ctx.addLine(to: CGPoint(x: statsX, y: y + h - 1))
        ctx.strokePath()

        let vals = dayData.bg.map { Double($0.sgv) }
        if !vals.isEmpty {
            let n = Double(vals.count)
            let avg = vals.reduce(0,+) / n
            let tir = Double(vals.filter { $0 >= 70 && $0 <= 180 }.count) / n * 100
            let totalInsulin = dayData.bolus.map { $0.value }.reduce(0, +) + dayData.smb.map { $0.value }.reduce(0, +)
            let dailyProgrammedBasal = calculateDailyProgrammedBasal(basalProfile: basalProfile)

            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: C_SLATE]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: C_INK]
            let tirC: UIColor = tir >= 70 ? C_IN : tir >= 50 ? C_HIGH : C_VLOW
            let tirA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: tirC]

            let padding: CGFloat = 8
            let col2X = statsX + statsW / 2

            // Row 1: Avg & TIR
            "Avg BG".draw(at: CGPoint(x: statsX + padding, y: y + 8), withAttributes: la)
            cfg.fmtBG(avg).draw(at: CGPoint(x: statsX + padding, y: y + 15), withAttributes: va)

            "TIR".draw(at: CGPoint(x: col2X, y: y + 8), withAttributes: la)
            String(format: "%.0f%%", tir).draw(at: CGPoint(x: col2X, y: y + 15), withAttributes: tirA)

            // Divider
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: statsX + 5, y: y + 30))
            ctx.addLine(to: CGPoint(x: x + w - 5, y: y + 30))
            ctx.strokePath()

            // Row 2: Bolus & Basal
            "Bolus Total".draw(at: CGPoint(x: statsX + padding, y: y + 36), withAttributes: la)
            String(format: "%.1f U", totalInsulin).draw(at: CGPoint(x: statsX + padding, y: y + 43), withAttributes: va)

            "Basal Sched".draw(at: CGPoint(x: col2X, y: y + 36), withAttributes: la)
            String(format: "%.1f U", dailyProgrammedBasal).draw(at: CGPoint(x: col2X, y: y + 43), withAttributes: va)

            // Divider
            ctx.move(to: CGPoint(x: statsX + 5, y: y + 58))
            ctx.addLine(to: CGPoint(x: x + w - 5, y: y + 58))
            ctx.strokePath()

            // Row 3: Coverage
            "Data Coverage".draw(at: CGPoint(x: statsX + padding, y: y + 64), withAttributes: la)
            let coverage = String(format: "%.0f%%", Double(vals.count) / 2.88)
            "\(vals.count) pts (\(coverage))".draw(at: CGPoint(x: statsX + padding, y: y + 71), withAttributes: va)
        }

        let chartX = x + 10; let chartW = w - 140
        let chartY = y + 22
        let axisLabelArea: CGFloat = 12
        let chartH = h - 22 - axisLabelArea

        // Daily chart palette with stronger visual separation.
        let dailyCarbColor = UIColor(red: 0.92, green: 0.50, blue: 0.18, alpha: 1)
        let dailyBasalColor = UIColor(red: 0.38, green: 0.46, blue: 0.62, alpha: 1)

        guard !dayData.bg.isEmpty else { return }

        let insulinLaneH = chartH * 0.24
        let insulinLaneY = chartY + chartH - insulinLaneH
        let bgInsulinGap: CGFloat = 4
        let glucosePlotBottomY = insulinLaneY - bgInsulinGap
        let glucosePlotH = max(glucosePlotBottomY - chartY, 24)

        ctx.saveGState()
        ctx.clip(to: CGRect(x: chartX, y: chartY, width: chartW, height: chartH))

        let bgMin: CGFloat = 40; let bgMax: CGFloat = 320; let bgRng = bgMax - bgMin
        func gy(_ bg: Double) -> CGFloat { chartY + glucosePlotH - (CGFloat(bg) - bgMin) / bgRng * glucosePlotH }
        func tx(_ ts: Double) -> CGFloat {
            let cal = dateTimeUtils.displayCalendar()
            let d = Date(timeIntervalSince1970: ts)
            let c = cal.dateComponents([.hour, .minute], from: d)
            let min = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
            return chartX + CGFloat(min / (24 * 60)) * chartW
        }

        ctx.setFillColor(C_IN.withAlphaComponent(0.06).cgColor)
        ctx.fill(CGRect(x: chartX, y: gy(180), width: chartW, height: gy(70) - gy(180)))

        ctx.setLineDash(phase: 0, lengths: [2, 2]); ctx.setLineWidth(0.4)
        ctx.setStrokeColor(C_LOW.withAlphaComponent(0.4).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: gy(70))); ctx.addLine(to: CGPoint(x: chartX + chartW, y: gy(70))); ctx.strokePath()
        ctx.setStrokeColor(C_HIGH.withAlphaComponent(0.4).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: gy(180))); ctx.addLine(to: CGPoint(x: chartX + chartW, y: gy(180))); ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        ctx.setStrokeColor(C_BORDER.withAlphaComponent(0.5).cgColor); ctx.setLineWidth(0.25)
        for h2 in stride(from: 3, through: 21, by: 3) {
            let hx = chartX + CGFloat(h2) / 24 * chartW
            ctx.move(to: CGPoint(x: hx, y: chartY)); ctx.addLine(to: CGPoint(x: hx, y: chartY + chartH)); ctx.strokePath()
        }

        // Dedicated insulin lane to declutter the lower portion of the chart.
        ctx.setFillColor(C_CLOUD.withAlphaComponent(0.55).cgColor)
        ctx.fill(CGRect(x: chartX, y: insulinLaneY, width: chartW, height: insulinLaneH))
        ctx.setStrokeColor(C_BORDER.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(0.25)
        ctx.move(to: CGPoint(x: chartX, y: insulinLaneY))
        ctx.addLine(to: CGPoint(x: chartX + chartW, y: insulinLaneY))
        ctx.strokePath()

        if !dayData.basal.isEmpty || !basalProfile.isEmpty {
            let actualBasal = dayData.basal.sorted { $0.date < $1.date }
            let scheduledBasal = basalProfile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }
            let actualMax = actualBasal.map { $0.basalRate }.max() ?? 0
            let scheduledMax = scheduledBasal.map { $0.value }.max() ?? 0
            let maxR = Swift.max(actualMax, scheduledMax, 0.01)

            // Clean solid step-line for actual basal.
            if !actualBasal.isEmpty {
                let stepPath = CGMutablePath()
                var lastPoint: CGPoint?
                for pt in actualBasal {
                    let px = tx(pt.date)
                    let py = insulinLaneY + insulinLaneH - CGFloat(pt.basalRate / maxR) * insulinLaneH
                    if let prev = lastPoint {
                        stepPath.addLine(to: CGPoint(x: px, y: prev.y))
                        stepPath.addLine(to: CGPoint(x: px, y: py))
                    } else {
                        stepPath.move(to: CGPoint(x: px, y: py))
                    }
                    lastPoint = CGPoint(x: px, y: py)
                }
                if let last = lastPoint {
                    stepPath.addLine(to: CGPoint(x: chartX + chartW, y: last.y))
                }

                ctx.setStrokeColor(dailyBasalColor.cgColor)
                ctx.setLineWidth(1.0)
                ctx.addPath(stepPath)
                ctx.strokePath()
            }

            // Dotted step-line for scheduled basal profile.
            if !scheduledBasal.isEmpty {
                let schedPath = CGMutablePath()
                var lastPoint: CGPoint?
                for pt in scheduledBasal {
                    let secs = Swift.max(0, Swift.min(pt.timeAsSeconds, 24 * 60 * 60))
                    let px = chartX + CGFloat(Double(secs) / Double(24 * 60 * 60)) * chartW
                    let py = insulinLaneY + insulinLaneH - CGFloat(pt.value / maxR) * insulinLaneH
                    if let prev = lastPoint {
                        schedPath.addLine(to: CGPoint(x: px, y: prev.y))
                        schedPath.addLine(to: CGPoint(x: px, y: py))
                    } else {
                        schedPath.move(to: CGPoint(x: px, y: py))
                    }
                    lastPoint = CGPoint(x: px, y: py)
                }
                if let last = lastPoint {
                    schedPath.addLine(to: CGPoint(x: chartX + chartW, y: last.y))
                }

                ctx.setStrokeColor(dailyBasalColor.withAlphaComponent(0.7).cgColor)
                ctx.setLineWidth(0.9)
                ctx.setLineDash(phase: 0, lengths: [2, 2])
                ctx.addPath(schedPath)
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
            }
        }

        // Draw carbs as orange diamonds in the top event row.
        var carbPositions: [CGFloat] = []
        for carb in dayData.carbs {
            let cx = tx(carb.date)
            let cy = chartY + 4
            let carbRadius: CGFloat = 2.5
            let diamond = CGMutablePath()
            diamond.move(to: CGPoint(x: cx, y: cy - carbRadius))
            diamond.addLine(to: CGPoint(x: cx + carbRadius, y: cy))
            diamond.addLine(to: CGPoint(x: cx, y: cy + carbRadius))
            diamond.addLine(to: CGPoint(x: cx - carbRadius, y: cy))
            diamond.closeSubpath()
            ctx.setFillColor(dailyCarbColor.withAlphaComponent(0.82).cgColor)
            ctx.addPath(diamond)
            ctx.fillPath()
            carbPositions.append(cx)
        }

        // Move SMB/Auto corrections into the top event row to declutter the bottom insulin lane.
        for smb in dayData.smb {
            let cx = tx(smb.date)
            let nearCarb = carbPositions.contains { abs($0 - cx) < 5 }
            let cy = chartY + (nearCarb ? 12 : 9)
            let radius: CGFloat = 2.0
            let diamond = CGMutablePath()
            diamond.move(to: CGPoint(x: cx, y: cy - radius))
            diamond.addLine(to: CGPoint(x: cx + radius, y: cy))
            diamond.addLine(to: CGPoint(x: cx, y: cy + radius))
            diamond.addLine(to: CGPoint(x: cx - radius, y: cy))
            diamond.closeSubpath()
            ctx.setFillColor(C_SMB.withAlphaComponent(0.82).cgColor)
            ctx.addPath(diamond)
            ctx.fillPath()
        }

        for bolus in dayData.bolus {
            let bx = tx(bolus.date)
            let fixedBolusHeight = min(insulinLaneH * 0.55, 8.0)
            let barRect = CGRect(x: bx - 2.3, y: chartY + chartH - fixedBolusHeight, width: 4.6, height: fixedBolusHeight)
            ctx.setFillColor(C_BOLUS.withAlphaComponent(0.82).cgColor)
            ctx.fill(barRect)
        }

        let sortedBG = dayData.bg.sorted(by: { $0.date < $1.date })

        if sortedBG.count > 1 {
            ctx.setLineWidth(1.15)
            for i in 0 ..< (sortedBG.count - 1) {
                let current = sortedBG[i]
                let next = sortedBG[i + 1]
                let sx = tx(current.date)
                let sy = gy(Double(current.sgv))
                let ex = tx(next.date)
                let ey = gy(Double(next.sgv))
                ctx.setStrokeColor(bgColor(Double(current.sgv)).withAlphaComponent(0.92).cgColor)
                ctx.move(to: CGPoint(x: sx, y: sy))
                ctx.addLine(to: CGPoint(x: ex, y: ey))
                ctx.strokePath()
            }
        }

        for r in sortedBG {
            let rx = tx(r.date)
            let ry = gy(Double(r.sgv))
            let pointColor = bgColor(Double(r.sgv))
            ctx.setFillColor(pointColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: rx - 1.55, y: ry - 1.55, width: 3.1, height: 3.1))
            ctx.setStrokeColor(C_WHITE.withAlphaComponent(0.8).cgColor)
            ctx.setLineWidth(0.4)
            ctx.strokeEllipse(in: CGRect(x: rx - 1.55, y: ry - 1.55, width: 3.1, height: 3.1))
        }

        ctx.restoreGState()

        // Target tags in compact pills improve visibility over dense traces.
        let targetTextA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 5.4), .foregroundColor: C_WHITE]
        func drawTargetTag(_ text: String, centerY: CGFloat) {
            let padX: CGFloat = 2.8
            let padY: CGFloat = 1.1
            let textSize = (text as NSString).size(withAttributes: targetTextA)
            let tagRect = CGRect(
                x: chartX + chartW - textSize.width - (padX * 2) - 1.5,
                y: centerY - (textSize.height + padY * 2) / 2,
                width: textSize.width + padX * 2,
                height: textSize.height + padY * 2
            )
            let tagPath = UIBezierPath(roundedRect: tagRect, cornerRadius: 2.6)
            ctx.setFillColor(C_INK.withAlphaComponent(0.76).cgColor)
            ctx.addPath(tagPath.cgPath)
            ctx.fillPath()
            (text as NSString).draw(at: CGPoint(x: tagRect.minX + padX, y: tagRect.minY + padY), withAttributes: targetTextA)
        }
        drawTargetTag("70", centerY: gy(70))
        drawTargetTag("180", centerY: gy(180))

        let axA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: C_SLATE]
        let axisLabelY = chartY + chartH + 4
        for h2 in [0, 6, 12, 18, 24] {
            let hx = chartX + CGFloat(h2) / 24 * chartW
            let lbl = String(format: "%02d", h2)
            let sz = (lbl as NSString).size(withAttributes: axA)
            (lbl as NSString).draw(at: CGPoint(x: hx - sz.width / 2, y: axisLabelY), withAttributes: axA)
        }

        // Legend right-aligned beside the graph so it cannot collide with the date heading.
        let legendItems: [(String, UIColor)] = [
            ("— BG", C_TIR_IN),
            ("◆ Carbs", dailyCarbColor),
            ("▮ Bolus", C_BOLUS),
            ("◆ SMB/Auto", C_SMB),
            ("— Basal actual", dailyBasalColor),
            ("⋯ Basal scheduled", dailyBasalColor.withAlphaComponent(0.72)),
        ]
        let lgA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: C_SLATE]
        let legendGap: CGFloat = 5
        let legendTotalWidth = legendItems.reduce(CGFloat(0)) { partial, item in
            partial + (item.0 as NSString).size(withAttributes: lgA).width
        } + legendGap * CGFloat(max(legendItems.count - 1, 0))

        let rightAlignedLegendX = statsX - 6 - legendTotalWidth
        let dayLabelRightEdge = x + 10 + (dayLabel as NSString).size(withAttributes: dlA).width
        let minLegendX = dayLabelRightEdge + 8
        let legendY: CGFloat = rightAlignedLegendX < minLegendX ? y + 16 : y + 7

        var lgX = rightAlignedLegendX
        for (lbl, clr) in legendItems {
            let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: clr]
            (lbl as NSString).draw(at: CGPoint(x: lgX, y: legendY), withAttributes: a)
            lgX += (lbl as NSString).size(withAttributes: lgA).width + legendGap
        }
    }

    // MARK: - Footer

    private static func drawFooter(ctx: CGContext, r: CGRect, cfg _: EndoReportConfig,
                                   stats: ReportStats, page: Int)
    {
        let fy = r.height - 28
        ctx.setFillColor(C_INK.cgColor); ctx.fill(CGRect(x: 0, y: fy, width: r.width, height: 28))
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_WHITE.withAlphaComponent(0.5)]
        "Loop Follow — for informational purposes only. Not a substitute for professional medical advice."
            .draw(at: CGPoint(x: 30, y: fy + 4), withAttributes: a)
        let df = DateFormatter(); df.dateFormat = "MMM d, yyyy"
        let meta = "Generated: \(df.string(from: Date()))  •  \(Int(stats.days.rounded())) Days  •  \(stats.readingCount) readings  •  Page \(page)"
        let msz = (meta as NSString).size(withAttributes: a)
        (meta as NSString).draw(at: CGPoint(x: r.width - 30 - msz.width, y: fy + 4), withAttributes: a)
    }
}
