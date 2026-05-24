// LoopFollow
// EndoReportGenerator.swift

import PDFKit
import UIKit

// MARK: - Config — defined in EndoReportView.swift, used here by reference

enum EndoReportGenerator {
    enum ReportError: LocalizedError {
        case noData
        var errorDescription: String? { "No CGM data available for the selected date range." }
    }

    // MARK: - Entry point

    static func generate(config: EndoReportConfig, dataService: StatsDataService) throws -> URL {
        let bgData = dataService.getBGData()
        guard !bgData.isEmpty else { throw ReportError.noData }

        let agpData = AGPCalculator.calculate(bgData: bgData)
        let tirData = TIRCalculator.calculate(bgData: bgData)
        let stats = ReportStats(bgData: bgData, dataService: dataService)
        let patterns = TimePatterns(bgData: bgData)
        let boluses = dataService.getBolusData()
        let smbs = dataService.getSMBData()
        let carbs = dataService.getCarbData()
        let basals = dataService.getBasalData()
        let simpleVM = SimpleStatsViewModel(dataService: dataService)
        simpleVM.calculateStats()

        let pageRect = CGRect(origin: .zero, size: CGSize(width: 612, height: 792))
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EndoReport_\(Int(Date().timeIntervalSince1970)).pdf")

        // Group days newest-first
        let dailyData = groupByDay(bgData: bgData, boluses: boluses, smbs: smbs, basals: basals, carbs: carbs)
            .sorted { $0.key > $1.key }

        let data = renderer.pdfData { ctx in
            // Page 1 — Summary
            ctx.beginPage()
            drawSummaryPage(ctx: ctx.cgContext, r: pageRect, cfg: config,
                            bgData: bgData, agpData: agpData, tirData: tirData,
                            stats: stats, patterns: patterns,
                            boluses: boluses, smbs: smbs, carbs: carbs,
                            simpleVM: simpleVM)

            // Pages 2+ — Daily breakdowns
            if config.includeDailyBreakdown && !dailyData.isEmpty {
                let rowH: CGFloat = 88
                let rowGap: CGFloat = 6
                let topY: CGFloat = 52 // after page header
                let botY: CGFloat = 762 // before footer
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
                                   day: day, dayData: dayData, cfg: config,
                                   simpleVM: simpleVM)
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
        let readingCount: Int
        init(bgData: [ShareGlucoseData], dataService: StatsDataService) {
            let v = bgData.map { Double($0.sgv) }; let n = Double(v.count)
            let m = v.reduce(0,+) / n
            let variance = v.map { ($0 - m) * ($0 - m) }.reduce(0,+) / n
            avg = m; stdDev = sqrt(variance); cv = stdDev / m * 100; eA1C = (m + 46.7) / 28.7
            minBG = v.min() ?? 0; maxBG = v.max() ?? 0; readingCount = v.count
            days = Swift.max(dataService.endDate.timeIntervalSince1970 - dataService.startDate.timeIntervalSince1970, 86400) / 86400
            sensorPct = Swift.min(Double(v.count) / (days * 288) * 100, 100)
            tir = Double(v.filter { $0 >= 70 && $0 <= 180 }.count) / n * 100
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
    private static let C_BASAL = UIColor(red: 0.102, green: 0.451, blue: 0.933, alpha: 0.65)

    private static func bgColor(_ bg: Double) -> UIColor {
        switch bg { case ..<54: return C_VLOW; case ..<70: return C_LOW; case ...180: return C_IN; case ...250: return C_HIGH; default: return C_VHIGH }
    }

    // MARK: - Page 1: Summary

    private static func drawSummaryPage(
        ctx: CGContext, r: CGRect, cfg: EndoReportConfig,
        bgData _: [ShareGlucoseData], agpData: [AGPDataPoint], tirData: [TIRDataPoint],
        stats: ReportStats, patterns: TimePatterns,
        boluses: [MainViewController.bolusGraphStruct],
        smbs: [MainViewController.bolusGraphStruct],
        carbs: [MainViewController.carbGraphStruct],
        simpleVM: SimpleStatsViewModel
    ) {
        let m: CGFloat = 30
        var y = drawHero(ctx: ctx, r: r, cfg: cfg, stats: stats)

        y = sectionHdr("GLUCOSE SUMMARY", y: y + 10, m: m, w: r.width, cfg: cfg, ctx: ctx)

        // Stat grid (left) + TIR bar (right)
        let gridW: CGFloat = r.width - m * 2 - 158
        let cw = gridW / 2 - 3; let ch: CGFloat = 44
        let cards: [(String, String, Bool)] = [
            ("TIME IN RANGE", String(format: "%.0f%%", stats.tir), true),
            ("GMI (EST. A1C)", String(format: "%.1f%%", stats.eA1C), false),
            ("AVERAGE", cfg.fmtBG(stats.avg) + " \(cfg.units)", false),
            ("STD DEVIATION", cfg.fmtBG(stats.stdDev), false),
            ("CV", String(format: "%.0f%%", stats.cv), false),
            ("READINGS", "\(stats.readingCount)", false),
        ]
        var gy = y + 5
        for (i, c) in cards.enumerated() {
            statCard(c.0, val: c.1, x: m + CGFloat(i % 2) * (cw + 6), y: gy + CGFloat(i / 2) * (ch + 4),
                     w: cw, h: ch, accent: c.2, cfg: cfg, ctx: ctx)
        }
        drawTIRBar(tirData: tirData, stats: stats, x: m + gridW + 10, y: y + 5,
                   w: 148, h: ch * 3 + 8, cfg: cfg, ctx: ctx)
        y = gy + CGFloat(3) * (ch + 4) + 6

        // Time-of-day strip
        y = timeStrip(patterns: patterns, cfg: cfg, y: y + 4, m: m, w: r.width, ctx: ctx)

        // Insulin
        if !boluses.isEmpty || !smbs.isEmpty {
            y = sectionHdr("INSULIN DELIVERY", y: y + 8, m: m, w: r.width, cfg: cfg, ctx: ctx)
            y = insulinSection(boluses: boluses, smbs: smbs, simpleVM: simpleVM,
                               stats: stats, cfg: cfg, y: y + 4, m: m, w: r.width, ctx: ctx)
        }

        // Nutrition
        if !carbs.isEmpty {
            y = sectionHdr("NUTRITION & MEALS", y: y + 6, m: m, w: r.width, cfg: cfg, ctx: ctx)
            y = nutritionSection(carbs: carbs, stats: stats, cfg: cfg, y: y + 4, m: m, w: r.width, ctx: ctx)
        }

        // Therapy settings if entered
        let hasSettings = !cfg.carbRatio.isEmpty || !cfg.isf.isEmpty || !cfg.basalRate.isEmpty || !cfg.targetGlucose.isEmpty
        if hasSettings {
            y = sectionHdr("CURRENT THERAPY SETTINGS", y: y + 6, m: m, w: r.width, cfg: cfg, ctx: ctx)
            var rows: [(String, String)] = []
            if !cfg.carbRatio.isEmpty { rows.append(("Carb Ratio (CR)", "\(cfg.carbRatio) g/U")) }
            if !cfg.isf.isEmpty { rows.append(("Insulin Sensitivity (ISF)", "\(cfg.isf) \(cfg.units)/U")) }
            if !cfg.basalRate.isEmpty { rows.append(("Basal Rate", "\(cfg.basalRate) U/hr")) }
            if !cfg.targetGlucose.isEmpty { rows.append(("Target Glucose", "\(cfg.targetGlucose) \(cfg.units)")) }
            y = metricTable(rows, y: y + 4, m: m, w: r.width, cfg: cfg, ctx: ctx)
        }

        // Device info
        let hasDevice = !cfg.pumpDevice.isEmpty || !cfg.cgmDevice.isEmpty || !cfg.insulinType.isEmpty
        if hasDevice {
            y = sectionHdr("DEVICES & INSULIN", y: y + 6, m: m, w: r.width, cfg: cfg, ctx: ctx)
            var rows: [(String, String)] = []
            if !cfg.aidSystem.isEmpty { rows.append(("AID System", cfg.aidSystem)) }
            if !cfg.pumpDevice.isEmpty { rows.append(("Pump", cfg.pumpDevice)) }
            if !cfg.cgmDevice.isEmpty { rows.append(("CGM", cfg.cgmDevice)) }
            if !cfg.insulinType.isEmpty { rows.append(("Insulin", cfg.insulinType)) }
            y = metricTable(rows, y: y + 4, m: m, w: r.width, cfg: cfg, ctx: ctx)
        }

        // AGP — fixed layout with reserved space, no overflow
        let agpAvail = r.height - y - 50 // leave room for footer
        if !agpData.isEmpty, agpAvail >= 100 {
            y = sectionHdr("AMBULATORY GLUCOSE PROFILE", y: y + 6, m: m, w: r.width, cfg: cfg, ctx: ctx)
            let agpH = Swift.min(agpAvail - 24, 118)
            drawAGP(agpData: agpData, x: m, y: y + 4, w: r.width - m * 2, h: agpH, cfg: cfg, ctx: ctx)
        }

        drawFooter(ctx: ctx, r: r, cfg: cfg, stats: stats, page: 1)
    }

    // MARK: - Hero header

    @discardableResult
    private static func drawHero(ctx: CGContext, r: CGRect, cfg: EndoReportConfig, stats: ReportStats) -> CGFloat {
        let h: CGFloat = 100; let ac = accent(cfg); let ad = accentDark(cfg)
        ctx.setFillColor(ac.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: h))
        ctx.setFillColor(ad.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: 21))

        // "LOOP FOLLOW" spaced out
        let a1: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: C_WHITE.withAlphaComponent(0.8), .kern: 3.0]
        "LOOP FOLLOW".draw(at: CGPoint(x: 32, y: 5), withAttributes: a1)

        let a2: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 21), .foregroundColor: C_WHITE]
        "Endocrinologist Visit Report".draw(at: CGPoint(x: 32, y: 22), withAttributes: a2)

        let a3: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9.5), .foregroundColor: C_WHITE.withAlphaComponent(0.82)]
        "Automated Insulin Delivery Performance Summary".draw(at: CGPoint(x: 32, y: 50), withAttributes: a3)

        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        let ds = "\(df.string(from: cfg.startDate)) — \(df.string(from: cfg.endDate)) (\(Int(stats.days.rounded())) Days)"
        let a4: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: C_WHITE.withAlphaComponent(0.68)]
        ds.draw(at: CGPoint(x: 32, y: 66), withAttributes: a4)

        // AID badge
        if !cfg.aidSystem.isEmpty {
            let badge = "▶ \(cfg.aidSystem)"
            let ba: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: C_WHITE.withAlphaComponent(0.9)]
            let bsz = (badge as NSString).size(withAttributes: ba)
            let bx = r.width - 32 - bsz.width - 10; let by: CGFloat = 66
            ctx.setFillColor(ad.cgColor); ctx.fill(CGRect(x: bx - 4, y: by - 1, width: bsz.width + 12, height: 12))
            (badge as NSString).draw(at: CGPoint(x: bx + 2, y: by), withAttributes: ba)
        }

        // Right side info
        let a5: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: C_WHITE.withAlphaComponent(0.85)]
        var lines: [String] = []
        if !cfg.patientName.isEmpty { lines.append("Patient: \(cfg.patientName)") }
        if !cfg.providerName.isEmpty { lines.append("Provider: \(cfg.providerName)") }
        if !cfg.dateOfBirth.isEmpty { lines.append("DOB: \(cfg.dateOfBirth)") }
        if !cfg.diagnosisDate.isEmpty { lines.append("Dx: \(cfg.diagnosisDate)") }
        for (i, l) in lines.enumerated() {
            let sz = (l as NSString).size(withAttributes: a5)
            (l as NSString).draw(at: CGPoint(x: r.width - 34 - sz.width, y: 22 + CGFloat(i) * 14), withAttributes: a5)
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
        return y + 19
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
        let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: ac ? accent(cfg) : C_INK]
        (label as NSString).draw(at: CGPoint(x: x + 8, y: y + 5), withAttributes: la)
        (val as NSString).draw(at: CGPoint(x: x + 8, y: y + 16), withAttributes: va)
    }

    // MARK: - TIR vertical bar

    private static func drawTIRBar(tirData: [TIRDataPoint], stats _: ReportStats,
                                   x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                   cfg: EndoReportConfig, ctx: CGContext)
    {
        guard let avg = tirData.first(where: { $0.period == .average }) else { return }
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r)
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r)
        let ta: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: C_SLATE]
        "Time in Range".draw(at: CGPoint(x: x + 8, y: y + 6), withAttributes: ta)
        let bx = x + 10; let bw: CGFloat = 16; let by = y + 22; let bh = h - 40
        let segs: [(Double, UIColor, String)] = [(avg.veryHigh, C_VHIGH, "Very High"), (avg.high, C_HIGH, "High"),
                                                 (avg.inRange, C_IN, "In Range"), (avg.low, C_LOW, "Low"), (avg.veryLow, C_VLOW, "Very Low")]
        var sy = by
        for (pct, clr, label) in segs {
            let sh = CGFloat(pct / 100) * bh
            if sh > 0 { ctx.setFillColor(clr.cgColor); ctx.fill(CGRect(x: bx, y: sy, width: bw, height: sh)) }
            if sh >= 10 {
                let ps = String(format: "%.0f%%", pct)
                let pa: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: label == "In Range" ? accent(cfg) : C_SLATE]
                let sa: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6), .foregroundColor: C_SLATE]
                (ps as NSString).draw(at: CGPoint(x: bx + bw + 4, y: sy + sh / 2 - 8), withAttributes: pa)
                if sh >= 18 { (label as NSString).draw(at: CGPoint(x: bx + bw + 4, y: sy + sh / 2), withAttributes: sa) }
            }
            sy += sh
        }
        let na: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: C_SLATE]
        "Target: 70-180".draw(at: CGPoint(x: x + 5, y: y + h - 20), withAttributes: na)
        "Tight: 70-140".draw(at: CGPoint(x: x + 5, y: y + h - 12), withAttributes: na)
        "1% ≈ 15 min".draw(at: CGPoint(x: x + 5, y: y + h - 4), withAttributes: na)
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
        let cw = (w - m * 2) / CGFloat(periods.count); let ch: CGFloat = 40; let cy = y + 13
        for (i, p) in periods.enumerated() {
            let cx = m + CGFloat(i) * cw
            let rr = CGRect(x: cx, y: cy, width: cw - 2, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(rr)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(rr)
            guard p.count > 0 else { continue }
            let disp = cfg.fmtBG(p.avg)
            let vc: UIColor = p.avg < 70 ? C_LOW : p.avg < 140 ? accent(cfg) : p.avg < 180 ? C_INK : C_HIGH
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: vc]
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
            let vsz = (disp as NSString).size(withAttributes: va)
            let lsz = (p.label as NSString).size(withAttributes: la)
            (disp as NSString).draw(at: CGPoint(x: cx + (cw - 2 - vsz.width) / 2, y: cy + 5), withAttributes: va)
            (p.label as NSString).draw(at: CGPoint(x: cx + (cw - 2 - lsz.width) / 2, y: cy + 27), withAttributes: la)
        }
        return cy + ch + 4
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
        let cw = (w - m * 2) / 3 - 4; let ch: CGFloat = 40
        for (i, c) in cards.enumerated() {
            let cx = m + CGFloat(i) * (cw + 4)
            let r2 = CGRect(x: cx, y: y, width: cw, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r2)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r2)
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.4]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: C_INK]
            (c.0 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 4), withAttributes: la)
            (c.1 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 14), withAttributes: va)
        }
        let ty = y + ch + 5
        let total = (boluses + smbs).map { $0.value }.reduce(0,+)
        let rows: [(String, String)] = [
            ("Correction Boluses", "\(boluses.count)"),
            ("SMB / Auto-Corrections", "\(smbs.count)"),
            ("Total Bolus Insulin", String(format: "%.1f U", total)),
            ("Programmed Basal", simpleVM.programmedBasal != nil ? String(format: "%.2f U/day", simpleVM.programmedBasal!) : "—"),
            ("Actual Basal", simpleVM.actualBasal != nil ? String(format: "%.2f U/day", simpleVM.actualBasal!) : "—"),
            ("Positive Temp Basal", simpleVM.totalPositiveBasal != nil ? String(format: "+%.2f U/day", simpleVM.totalPositiveBasal!) : "—"),
            ("Negative Temp Basal", simpleVM.totalNegativeBasal != nil ? String(format: "%.2f U/day", simpleVM.totalNegativeBasal!) : "—"),
        ]
        return metricTable(rows, y: ty, m: m, w: w, cfg: cfg, ctx: ctx)
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
        let cw = (w - m * 2) / 3 - 4; let ch: CGFloat = 40
        for (i, c) in cards.enumerated() {
            let cx = m + CGFloat(i) * (cw + 4)
            let r2 = CGRect(x: cx, y: y, width: cw, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r2)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r2)
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.4]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: C_INK]
            (c.0 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 4), withAttributes: la)
            (c.1 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 14), withAttributes: va)
        }
        return y + ch + 6
    }

    // MARK: - Metric table

    @discardableResult
    private static func metricTable(_ rows: [(String, String)], y: CGFloat, m: CGFloat,
                                    w: CGFloat, cfg: EndoReportConfig, ctx: CGContext) -> CGFloat
    {
        let tw = w - m * 2; let hh: CGFloat = 13; let rh: CGFloat = 12; var cy = y
        ctx.setFillColor(accent(cfg).withAlphaComponent(0.10).cgColor)
        ctx.fill(CGRect(x: m, y: cy, width: tw, height: hh))
        let ha: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: accent(cfg), .kern: 0.4]
        "METRIC".draw(at: CGPoint(x: m + 6, y: cy + 3), withAttributes: ha)
        "VALUE".draw(at: CGPoint(x: m + tw * 0.62 + 6, y: cy + 3), withAttributes: ha)
        cy += hh
        for (i, row) in rows.enumerated() {
            ctx.setFillColor((i % 2 == 0 ? C_WHITE : C_CLOUD).cgColor)
            ctx.fill(CGRect(x: m, y: cy, width: tw, height: rh))
            let ka: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: C_INK]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: accent(cfg)]
            (row.0 as NSString).draw(at: CGPoint(x: m + 6, y: cy + 2), withAttributes: ka)
            (row.1 as NSString).draw(at: CGPoint(x: m + tw * 0.62 + 6, y: cy + 2), withAttributes: va)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: m, y: cy + rh)); ctx.addLine(to: CGPoint(x: m + tw, y: cy + rh)); ctx.strokePath()
            cy += rh
        }
        return cy + 5
    }

    // MARK: - AGP (clean, no overflow)

    private static func drawAGP(agpData: [AGPDataPoint], x: CGFloat, y: CGFloat,
                                w: CGFloat, h: CGFloat, cfg: EndoReportConfig, ctx: CGContext)
    {
        guard !agpData.isEmpty else { return }
        let lPad: CGFloat = 26; let bPad: CGFloat = 16
        let cw = w - lPad; let ch = h - bPad
        let cx = x + lPad; let cy = y

        ctx.setFillColor(UIColor(white: 0.985, alpha: 1).cgColor)
        ctx.fill(CGRect(x: cx, y: cy, width: cw, height: ch))

        let bgMin: CGFloat = 40; let bgRng: CGFloat = 320
        func gy(_ g: Double) -> CGFloat { cy + ch - (CGFloat(g) - bgMin) / bgRng * ch }
        func tx(_ mins: Int) -> CGFloat { cx + CGFloat(mins) / (24 * 60) * cw }

        // Target zone
        ctx.setFillColor(C_IN.withAlphaComponent(0.07).cgColor)
        ctx.fill(CGRect(x: cx, y: gy(180), width: cw, height: gy(70) - gy(180)))

        // Target lines
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        for (val, clr) in [(70.0, C_LOW), (180.0, C_HIGH)] {
            ctx.setStrokeColor(clr.withAlphaComponent(0.5).cgColor); ctx.setLineWidth(0.6)
            ctx.move(to: CGPoint(x: cx, y: gy(val))); ctx.addLine(to: CGPoint(x: cx + cw, y: gy(val))); ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // 5-95 band
        var band = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p95)); i == 0 ? band.move(to: p) : band.addLine(to: p)
        }
        for pt in agpData.reversed() {
            band.addLine(to: CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p5)))
        }
        band.closeSubpath()
        ctx.setFillColor(accent(cfg).withAlphaComponent(0.10).cgColor); ctx.addPath(band); ctx.fillPath()

        // IQR band
        var iqr = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p75)); i == 0 ? iqr.move(to: p) : iqr.addLine(to: p)
        }
        for pt in agpData.reversed() {
            iqr.addLine(to: CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p25)))
        }
        iqr.closeSubpath()
        ctx.setFillColor(accent(cfg).withAlphaComponent(0.25).cgColor); ctx.addPath(iqr); ctx.fillPath()

        // Median
        ctx.setStrokeColor(accent(cfg).cgColor); ctx.setLineWidth(1.6)
        var first = true
        for pt in agpData {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p50)); first ? ctx.move(to: p) : ctx.addLine(to: p); first = false
        }
        ctx.strokePath()

        // Y labels — strictly left of chart
        let axA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
        for bg in [70, 140, 180, 250] {
            let ly = gy(Double(bg)); guard ly >= cy, ly <= cy + ch else { continue }
            let lbl = cfg.isMMOL ? String(format: "%.1f", Double(bg) * 0.0555) : "\(bg)"
            let lsz = (lbl as NSString).size(withAttributes: axA)
            (lbl as NSString).draw(at: CGPoint(x: x + lPad - lsz.width - 3, y: ly - lsz.height / 2), withAttributes: axA)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.25)
            ctx.move(to: CGPoint(x: cx, y: ly)); ctx.addLine(to: CGPoint(x: cx + cw, y: ly)); ctx.strokePath()
        }

        // X labels — clamped below chart
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

        // Legend — bottom right, inside label zone
        let lgA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
        let lgItems: [(String, UIColor, Bool)] = [("Median", accent(cfg), false),
                                                  ("25–75th", accent(cfg).withAlphaComponent(0.4), true),
                                                  ("5–95th", accent(cfg).withAlphaComponent(0.18), true)]
        var lgX = cx + cw
        for item in lgItems.reversed() {
            let lsz = (item.0 as NSString).size(withAttributes: lgA)
            lgX -= lsz.width
            (item.0 as NSString).draw(at: CGPoint(x: lgX, y: cy + ch + 3), withAttributes: lgA)
            lgX -= 15
            item.2 ? { ctx.setFillColor(item.1.cgColor); ctx.fill(CGRect(x: lgX, y: cy + ch + 4, width: 12, height: 8)) }()
                : { ctx.setFillColor(item.1.cgColor); ctx.fill(CGRect(x: lgX, y: cy + ch + 7, width: 12, height: 2)) }()
            lgX -= 5
        }
    }

    // MARK: - Day row

    private static func drawDayRow(ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                   day: String, dayData: DayData, cfg: EndoReportConfig,
                                   simpleVM _: SimpleStatsViewModel)
    {
        // Card
        ctx.setFillColor(C_WHITE.cgColor); ctx.fill(CGRect(x: x, y: y, width: w, height: h))
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: x, y: y, width: w, height: h))
        ctx.setFillColor(accent(EndoReportConfig(patientName: "", dateOfBirth: "", diagnosisDate: "", providerName: "", insulinType: "", aidSystem: "", pumpDevice: "", cgmDevice: "", carbRatio: "", isf: "", basalRate: "", targetGlucose: "", units: cfg.units, accentColorHex: cfg.accentColorHex, includeDailyBreakdown: true, includeFatProtein: false, startDate: cfg.startDate, endDate: cfg.endDate)).cgColor)

        // Use cfg directly for accent
        ctx.setFillColor(cfg.accentColor.cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 3, height: h))

        // Day label
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let df2 = DateFormatter(); df2.dateFormat = "EEEE, MMM d, yyyy"
        let date = df.date(from: day) ?? Date()
        let dlA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: C_INK]
        df2.string(from: date).draw(at: CGPoint(x: x + 10, y: y + 5), withAttributes: dlA)

        // Right-side stats panel
        let vals = dayData.bg.map { Double($0.sgv) }
        let statsX = x + w - 130
        if !vals.isEmpty {
            let n = Double(vals.count)
            let avg = vals.reduce(0,+) / n
            let tir = Double(vals.filter { $0 >= 70 && $0 <= 180 }.count) / n * 100
            let totalBolus = (dayData.bolus + dayData.smb).map { $0.value }.reduce(0,+)
            // Basal estimate: sum basalRate * duration segments
            var basalTotal = 0.0
            let sortedBasal = dayData.basal.sorted { $0.date < $1.date }
            for i in 0 ..< sortedBasal.count - 1 {
                let dur = (sortedBasal[i + 1].date - sortedBasal[i].date) / 3600
                if dur > 0, dur < 4 { basalTotal += sortedBasal[i].basalRate * dur }
            }
            let total = totalBolus + basalTotal
            let bolusPct = total > 0 ? totalBolus / total * 100 : 0
            let basalPct = total > 0 ? basalTotal / total * 100 : 0

            let sa: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
            let sv: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: C_INK]
            let tirC: UIColor = tir >= 70 ? C_IN : tir >= 50 ? C_HIGH : C_VLOW
            let tirA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: tirC]
            let acA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: cfg.accentColor]

            // Row 1 — labels
            let cols: [(String, CGFloat)] = [("Avg", 0), ("TIR", 30), ("Bolus", 62), ("Basal", 95), ("B:Bas", 128)]
            for (lbl, ox) in cols {
                (lbl as NSString).draw(at: CGPoint(x: statsX + ox, y: y + 5), withAttributes: sa)
            }

            // Row 2 — values
            cfg.fmtBG(avg).draw(at: CGPoint(x: statsX, y: y + 14), withAttributes: sv)
            String(format: "%.0f%%", tir).draw(at: CGPoint(x: statsX + 28, y: y + 14), withAttributes: tirA)
            String(format: "%.1fU", totalBolus).draw(at: CGPoint(x: statsX + 60, y: y + 14), withAttributes: sv)
            (basalTotal > 0 ? String(format: "%.1fU", basalTotal) : "—").draw(at: CGPoint(x: statsX + 93, y: y + 14), withAttributes: sv)
            // Bolus:Basal ratio
            let ratioStr = total > 0 ? String(format: "%.0f:%.0f", bolusPct, basalPct) : "—"
            ratioStr.draw(at: CGPoint(x: statsX + 126, y: y + 14), withAttributes: acA)
        }

        // Chart area
        let chartX = x + 10; let chartW = w - 150
        let chartY = y + 26; let chartH = h - 32

        guard !dayData.bg.isEmpty else { return }

        let bgMin: CGFloat = 40; let bgMax: CGFloat = 320; let bgRng = bgMax - bgMin
        func gy(_ bg: Double) -> CGFloat { chartY + chartH - (CGFloat(bg) - bgMin) / bgRng * chartH }
        func tx(_ ts: Double) -> CGFloat {
            let cal = dateTimeUtils.displayCalendar()
            let d = Date(timeIntervalSince1970: ts)
            let c = cal.dateComponents([.hour, .minute], from: d)
            let min = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
            return chartX + CGFloat(min / (24 * 60)) * chartW
        }

        // Target zone
        ctx.setFillColor(C_IN.withAlphaComponent(0.06).cgColor)
        ctx.fill(CGRect(x: chartX, y: gy(180), width: chartW, height: gy(70) - gy(180)))

        // Target lines
        ctx.setLineDash(phase: 0, lengths: [2, 2]); ctx.setLineWidth(0.4)
        ctx.setStrokeColor(C_LOW.withAlphaComponent(0.4).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: gy(70))); ctx.addLine(to: CGPoint(x: chartX + chartW, y: gy(70))); ctx.strokePath()
        ctx.setStrokeColor(C_HIGH.withAlphaComponent(0.4).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: gy(180))); ctx.addLine(to: CGPoint(x: chartX + chartW, y: gy(180))); ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Hour grid
        ctx.setStrokeColor(C_BORDER.withAlphaComponent(0.5).cgColor); ctx.setLineWidth(0.25)
        for h2 in stride(from: 3, through: 21, by: 3) {
            let hx = chartX + CGFloat(h2) / 24 * chartW
            ctx.move(to: CGPoint(x: hx, y: chartY)); ctx.addLine(to: CGPoint(x: hx, y: chartY + chartH)); ctx.strokePath()
        }

        // Basal fill + line (bottom 25% of chart)
        if !dayData.basal.isEmpty {
            let bH = chartH * 0.25; let bY = chartY + chartH - bH
            let sorted = dayData.basal.sorted { $0.date < $1.date }
            let maxR = sorted.map { $0.basalRate }.max() ?? 1
            var path = CGMutablePath(); var first = true
            for pt in sorted {
                let px = tx(pt.date); let py = bY + bH - CGFloat(pt.basalRate / maxR) * bH
                first ? path.move(to: CGPoint(x: px, y: py)) : path.addLine(to: CGPoint(x: px, y: py)); first = false
            }
            if let last = sorted.last {
                path.addLine(to: CGPoint(x: tx(last.date), y: bY + bH))
                path.addLine(to: CGPoint(x: chartX, y: bY + bH)); path.closeSubpath()
                ctx.setFillColor(C_BASAL.withAlphaComponent(0.15).cgColor); ctx.addPath(path); ctx.fillPath()
            }
            var lp = CGMutablePath(); first = true
            for pt in sorted {
                let px = tx(pt.date); let py = bY + bH - CGFloat(pt.basalRate / maxR) * bH; first ? lp.move(to: CGPoint(x: px, y: py)) : lp.addLine(to: CGPoint(x: px, y: py)); first = false
            }
            ctx.setStrokeColor(C_BASAL.cgColor); ctx.setLineWidth(0.9); ctx.addPath(lp); ctx.strokePath()
        }

        // SMB bars (magenta, thinner)
        for smb in dayData.smb {
            let bx = tx(smb.date); let bh2 = CGFloat(Swift.min(smb.value / 15, 1)) * (chartH * 0.35)
            ctx.setFillColor(C_SMB.cgColor)
            ctx.fill(CGRect(x: bx - 1.2, y: chartY + chartH - bh2, width: 2.4, height: bh2))
        }

        // Bolus bars (purple)
        for bolus in dayData.bolus {
            let bx = tx(bolus.date); let bh2 = CGFloat(Swift.min(bolus.value / 15, 1)) * (chartH * 0.4)
            ctx.setFillColor(C_BOLUS.cgColor)
            ctx.fill(CGRect(x: bx - 1.5, y: chartY + chartH - bh2, width: 3, height: bh2))
        }

        // BG dots
        for r in dayData.bg.sorted { $0.date < $1.date } {
            let rx = tx(r.date); let ry = gy(Double(r.sgv))
            ctx.setFillColor(bgColor(Double(r.sgv)).cgColor)
            ctx.fillEllipse(in: CGRect(x: rx - 1.6, y: ry - 1.6, width: 3.2, height: 3.2))
        }

        // X-axis hour markers (just 00,06,12,18,24)
        let axA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: C_SLATE]
        for h2 in [0, 6, 12, 18, 24] {
            let hx = chartX + CGFloat(h2) / 24 * chartW
            let lbl = String(format: "%02d", h2)
            let sz = (lbl as NSString).size(withAttributes: axA)
            (lbl as NSString).draw(at: CGPoint(x: hx - sz.width / 2, y: chartY + chartH + 2), withAttributes: axA)
        }

        // Legend (first row only to save space)
        if day == day { // always show — could gate on first row
            let lgA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: C_SLATE]
            var lgX = chartX + chartW + 4
            for (lbl, clr) in [("● BG", C_IN), ("▮ Bolus", C_BOLUS), ("▮ SMB", C_SMB), ("— Basal", C_BASAL)] {
                let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 5.5), .foregroundColor: clr]
                (lbl as NSString).draw(at: CGPoint(x: lgX, y: chartY + 2), withAttributes: a)
                lgX += (lbl as NSString).size(withAttributes: lgA).width + 5
                if lgX > x + w - 4 { break }
            }
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

// MARK: - UIColor hex init
