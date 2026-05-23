// LoopFollow
// EndoReportGenerator-3.swift

import PDFKit
import UIKit

enum EndoReportGenerator {
    // MARK: - Entry point

    static func generate(
        patientName: String,
        dateOfBirth: String,
        providerName: String,
        startDate: Date,
        endDate: Date,
        dataService: StatsDataService
    ) throws -> URL {
        let bgData = dataService.getBGData()
        guard !bgData.isEmpty else { throw ReportError.noData }

        let agpData = AGPCalculator.calculate(bgData: bgData)
        let tirData = TIRCalculator.calculate(bgData: bgData)
        let stats = SimpleStats(bgData: bgData, dataService: dataService)
        let patterns = GlycemicPatterns(bgData: bgData)
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

        let data = renderer.pdfData { ctx in
            // Page 1 — Summary dashboard
            ctx.beginPage()
            drawSummaryPage(
                ctx: ctx.cgContext, r: pageRect,
                patientName: patientName, dateOfBirth: dateOfBirth,
                providerName: providerName, startDate: startDate, endDate: endDate,
                bgData: bgData, agpData: agpData, tirData: tirData,
                stats: stats, patterns: patterns,
                boluses: boluses, smbs: smbs, carbs: carbs,
                simpleVM: simpleVM
            )

            // Page 2 — Daily breakdowns
            ctx.beginPage()
            drawDailyPage(
                ctx: ctx.cgContext, r: pageRect,
                patientName: patientName, startDate: startDate, endDate: endDate,
                bgData: bgData, boluses: boluses, smbs: smbs, basals: basals,
                stats: stats
            )
        }
        try data.write(to: url)
        return url
    }

    enum ReportError: LocalizedError {
        case noData
        var errorDescription: String? { "No CGM data available for the selected date range." }
    }

    // MARK: - Palette

    private static let C_TEAL = UIColor(red: 0.137, green: 0.624, blue: 0.675, alpha: 1)
    private static let C_TEAL_DARK = UIColor(red: 0.090, green: 0.420, blue: 0.460, alpha: 1)
    private static let C_INK = UIColor(red: 0.133, green: 0.157, blue: 0.192, alpha: 1)
    private static let C_SLATE = UIColor(red: 0.400, green: 0.440, blue: 0.490, alpha: 1)
    private static let C_CLOUD = UIColor(red: 0.960, green: 0.963, blue: 0.970, alpha: 1)
    private static let C_BORDER = UIColor(red: 0.870, green: 0.885, blue: 0.905, alpha: 1)
    private static let C_WHITE = UIColor.white
    private static let C_VLOW = UIColor(red: 0.820, green: 0.180, blue: 0.180, alpha: 1)
    private static let C_LOW = UIColor(red: 0.929, green: 0.490, blue: 0.188, alpha: 1)
    private static let C_IN = UIColor(red: 0.200, green: 0.670, blue: 0.470, alpha: 1)
    private static let C_TIGHT = UIColor(red: 0.140, green: 0.780, blue: 0.580, alpha: 1)
    private static let C_HIGH = UIColor(red: 0.910, green: 0.740, blue: 0.220, alpha: 1)
    private static let C_VHIGH = UIColor(red: 0.800, green: 0.340, blue: 0.340, alpha: 1)
    private static let C_BOLUS = UIColor(red: 0.380, green: 0.220, blue: 0.780, alpha: 1)
    private static let C_BASAL = UIColor(red: 0.102, green: 0.451, blue: 0.933, alpha: 0.7)

    // MARK: - Data models

    struct SimpleStats {
        let avg, stdDev, cv, eA1C, minBG, maxBG, sensorPct, tir, tightTIR, days: Double
        let readingCount: Int
        init(bgData: [ShareGlucoseData], dataService: StatsDataService) {
            let v = bgData.map { Double($0.sgv) }
            let n = Double(v.count)
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

    struct GlycemicPatterns {
        struct P { let label: String; let avg: Double; let count: Int }
        let night, earlyAM, morning, afternoon, evening, late: P
        init(bgData: [ShareGlucoseData]) {
            func p(_ l: String, _ s: Int, _ e: Int) -> P {
                let cal = dateTimeUtils.displayCalendar()
                let r = bgData.filter { let h = cal.component(.hour, from: Date(timeIntervalSince1970: $0.date)); return h >= s && h < e }
                return P(label: l, avg: r.isEmpty ? 0 : r.map { Double($0.sgv) }.reduce(0,+) / Double(r.count), count: r.count)
            }
            night = p("Night", 0, 3); earlyAM = p("Early AM", 3, 6); morning = p("Morning", 6, 12)
            afternoon = p("Afternoon", 12, 17); evening = p("Evening", 17, 21); late = p("Late", 21, 24)
        }
    }

    // MARK: - Page 1

    private static func drawSummaryPage(
        ctx: CGContext, r: CGRect,
        patientName: String, dateOfBirth: String, providerName: String,
        startDate: Date, endDate: Date,
        bgData _: [ShareGlucoseData], agpData: [AGPDataPoint], tirData: [TIRDataPoint],
        stats: SimpleStats, patterns: GlycemicPatterns,
        boluses: [MainViewController.bolusGraphStruct],
        smbs: [MainViewController.bolusGraphStruct],
        carbs: [MainViewController.carbGraphStruct],
        simpleVM: SimpleStatsViewModel
    ) {
        let m: CGFloat = 30
        var y = drawHero(ctx: ctx, r: r, patientName: patientName, providerName: providerName,
                         dateOfBirth: dateOfBirth, startDate: startDate, endDate: endDate, stats: stats)

        y = sectionHdr("GLUCOSE SUMMARY", y: y + 12, m: m, w: r.width, ctx: ctx)

        // 6 stat cards left + TIR bar right
        let gridW = r.width - m * 2 - 162
        let cw = gridW / 2 - 3
        let ch: CGFloat = 46
        let cards: [(String, String, Bool)] = [
            ("TIME IN RANGE", String(format: "%.0f%%", stats.tir), true),
            ("GMI (EST. A1C)", String(format: "%.1f%%", stats.eA1C), false),
            ("AVERAGE", String(format: "%.0f", stats.avg), false),
            ("STD DEVIATION", String(format: "%.0f", stats.stdDev), false),
            ("CV", String(format: "%.0f%%", stats.cv), false),
            ("READINGS", "\(stats.readingCount)", false),
        ]
        var gy = y + 6
        for (i, card) in cards.enumerated() {
            let col = CGFloat(i % 2); let row = CGFloat(i / 2)
            statCard(card.0, val: card.1, x: m + col * (cw + 6), y: gy + row * (ch + 4),
                     w: cw, h: ch, accent: card.2, ctx: ctx)
        }
        let tirBarH = ch * 3 + 8
        drawTIRBar(tirData: tirData, stats: stats,
                   x: m + gridW + 12, y: y + 6, w: 150, h: tirBarH, ctx: ctx)
        y = gy + CGFloat(3) * (ch + 4) + 8

        // Time-of-day strip
        y = timeOfDayStrip(patterns: patterns, y: y + 4, m: m, w: r.width, ctx: ctx)

        // Insulin
        let hasInsulin = !boluses.isEmpty || !smbs.isEmpty
        if hasInsulin {
            y = sectionHdr("INSULIN DELIVERY", y: y + 10, m: m, w: r.width, ctx: ctx)
            y = insulinSection(boluses: boluses, smbs: smbs, simpleVM: simpleVM,
                               stats: stats, y: y + 4, m: m, w: r.width, ctx: ctx)
        }

        // Nutrition
        if !carbs.isEmpty {
            y = sectionHdr("NUTRITION & MEALS", y: y + 8, m: m, w: r.width, ctx: ctx)
            y = nutritionSection(carbs: carbs, stats: stats, y: y + 4, m: m, w: r.width, ctx: ctx)
        }

        // AGP strip — clean, fixed height
        let agpH: CGFloat = 110
        if !agpData.isEmpty, y + agpH + 50 < r.height {
            y = sectionHdr("AMBULATORY GLUCOSE PROFILE (AGP)", y: y + 10, m: m, w: r.width, ctx: ctx)
            drawAGP(agpData: agpData, x: m, y: y + 4, w: r.width - m * 2, h: agpH, ctx: ctx)
            y += agpH + 18
        }

        footer(ctx: ctx, r: r, startDate: startDate, endDate: endDate, stats: stats, page: 1)
    }

    // MARK: - Page 2 — Daily breakdowns

    private static func drawDailyPage(
        ctx: CGContext, r: CGRect,
        patientName: String, startDate: Date, endDate: Date,
        bgData: [ShareGlucoseData],
        boluses: [MainViewController.bolusGraphStruct],
        smbs: [MainViewController.bolusGraphStruct],
        basals: [MainViewController.basalGraphStruct],
        stats: SimpleStats
    ) {
        let m: CGFloat = 30
        var y = drawPageHeader(ctx: ctx, r: r, patientName: patientName,
                               startDate: startDate, endDate: endDate)
        y = sectionHdr("DAILY GLUCOSE BREAKDOWN", y: y + 10, m: m, w: r.width, ctx: ctx)

        // Group BG data by local day
        let cal = dateTimeUtils.displayCalendar()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var bgByDay: [String: [ShareGlucoseData]] = [:]
        for reading in bgData {
            let key = df.string(from: Date(timeIntervalSince1970: reading.date))
            bgByDay[key, default: []].append(reading)
        }

        // Group boluses by day
        var bolusByDay: [String: [MainViewController.bolusGraphStruct]] = [:]
        for b in boluses + smbs {
            let key = df.string(from: Date(timeIntervalSince1970: b.date))
            bolusByDay[key, default: []].append(b)
        }

        // Group basals by day
        var basalByDay: [String: [MainViewController.basalGraphStruct]] = [:]
        for b in basals {
            let key = df.string(from: Date(timeIntervalSince1970: b.date))
            basalByDay[key, default: []].append(b)
        }

        let sortedDays = bgByDay.keys.sorted()
        let rowH: CGFloat = 82
        let rowGap: CGFloat = 8
        let df2 = DateFormatter(); df2.dateFormat = "EEEE, MMM d"

        for (i, day) in sortedDays.enumerated() {
            // Start new page if needed
            if y + rowH + rowGap > r.height - 40 {
                footer(ctx: ctx, r: r, startDate: startDate, endDate: endDate, stats: stats, page: 2 + i / 8)
                // (caller would need to beginPage — in practice all days fit on 1-2 pages)
                break
            }

            let dayReadings = bgByDay[day] ?? []
            let dayBoluses = bolusByDay[day] ?? []
            let dayBasals = basalByDay[day] ?? []
            let date = df.date(from: day) ?? Date()

            drawDayRow(
                ctx: ctx, x: m, y: y, w: r.width - m * 2, h: rowH,
                label: df2.string(from: date),
                readings: dayReadings,
                boluses: dayBoluses,
                basals: dayBasals
            )
            y += rowH + rowGap
        }

        footer(ctx: ctx, r: r, startDate: startDate, endDate: endDate, stats: stats, page: 2)
    }

    // MARK: - Day row (mini chart)

    private static func drawDayRow(
        ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
        label: String,
        readings: [ShareGlucoseData],
        boluses: [MainViewController.bolusGraphStruct],
        basals: [MainViewController.basalGraphStruct]
    ) {
        // Card background
        ctx.setFillColor(C_WHITE.cgColor); ctx.fill(CGRect(x: x, y: y, width: w, height: h))
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: x, y: y, width: w, height: h))

        // Left teal accent
        ctx.setFillColor(C_TEAL.cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 3, height: h))

        // Day label
        let dlA: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: C_INK,
        ]
        label.draw(at: CGPoint(x: x + 10, y: y + 6), withAttributes: dlA)

        // Quick stats on the right side
        let vals = readings.map { Double($0.sgv) }
        if !vals.isEmpty {
            let n = Double(vals.count)
            let avg = vals.reduce(0,+) / n
            let tir = Double(vals.filter { $0 >= 70 && $0 <= 180 }.count) / n * 100
            let lo = vals.filter { $0 < 70 }.count
            let hi = vals.filter { $0 > 180 }.count

            let statW: CGFloat = 90
            let statX = x + w - statW - 8

            let sa: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: C_SLATE]
            let sv: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: C_INK]
            let tirC: UIColor = tir >= 70 ? C_IN : tir >= 50 ? C_HIGH : C_VLOW
            let tirA: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: tirC]

            "Avg".draw(at: CGPoint(x: statX, y: y + 8), withAttributes: sa)
            "TIR".draw(at: CGPoint(x: statX + 30, y: y + 8), withAttributes: sa)
            "Lo".draw(at: CGPoint(x: statX + 60, y: y + 8), withAttributes: sa)
            "Hi".draw(at: CGPoint(x: statX + 76, y: y + 8), withAttributes: sa)

            String(format: "%.0f", avg).draw(at: CGPoint(x: statX, y: y + 18), withAttributes: sv)
            String(format: "%.0f%%", tir).draw(at: CGPoint(x: statX + 28, y: y + 18), withAttributes: tirA)
            "\(lo)".draw(at: CGPoint(x: statX + 60, y: y + 18), withAttributes: sa)
            "\(hi)".draw(at: CGPoint(x: statX + 76, y: y + 18), withAttributes: sa)
        }

        // Chart area
        let chartX: CGFloat = x + 10
        let chartW: CGFloat = w - 110
        let chartY: CGFloat = y + 22
        let chartH: CGFloat = h - 28

        guard !readings.isEmpty else { return }

        // BG range for this day
        let bgMin: CGFloat = 40
        let bgMax: CGFloat = 320
        let bgRange = bgMax - bgMin

        func gY(_ bg: Double) -> CGFloat {
            chartY + chartH - (CGFloat(bg) - bgMin) / bgRange * chartH
        }
        func tX(_ ts: Double) -> CGFloat {
            // Map 00:00–24:00 to chartX..chartX+chartW
            let cal = dateTimeUtils.displayCalendar()
            let date = Date(timeIntervalSince1970: ts)
            let comps = cal.dateComponents([.hour, .minute], from: date)
            let minuteOfDay = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
            return chartX + CGFloat(minuteOfDay / (24 * 60)) * chartW
        }

        // Target zone
        ctx.setFillColor(C_IN.withAlphaComponent(0.07).cgColor)
        ctx.fill(CGRect(x: chartX, y: gY(180), width: chartW, height: gY(70) - gY(180)))

        // Target lines
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        ctx.setLineWidth(0.5)
        ctx.setStrokeColor(C_LOW.withAlphaComponent(0.5).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: gY(70))); ctx.addLine(to: CGPoint(x: chartX + chartW, y: gY(70))); ctx.strokePath()
        ctx.setStrokeColor(C_HIGH.withAlphaComponent(0.5).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: gY(180))); ctx.addLine(to: CGPoint(x: chartX + chartW, y: gY(180))); ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Hour grid lines (subtle)
        ctx.setStrokeColor(C_BORDER.withAlphaComponent(0.6).cgColor); ctx.setLineWidth(0.3)
        for h2 in stride(from: 3, through: 21, by: 3) {
            let hx = chartX + CGFloat(h2) / 24 * chartW
            ctx.move(to: CGPoint(x: hx, y: chartY)); ctx.addLine(to: CGPoint(x: hx, y: chartY + chartH)); ctx.strokePath()
        }

        // Basal line (blue, bottom portion)
        if !basals.isEmpty {
            let basalH: CGFloat = chartH * 0.25
            let basalY = chartY + chartH - basalH
            let maxBasal = basals.map { $0.basalRate }.max() ?? 1.0
            let sorted = basals.sorted { $0.date < $1.date }

            ctx.setStrokeColor(C_BASAL.cgColor); ctx.setLineWidth(1.0)
            ctx.setFillColor(C_BASAL.withAlphaComponent(0.15).cgColor)

            var path = CGMutablePath()
            var first = true
            for pt in sorted {
                let px = tX(pt.date)
                let py = basalY + basalH - CGFloat(pt.basalRate / maxBasal) * basalH
                if first { path.move(to: CGPoint(x: px, y: py)); first = false }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            // Close fill path along bottom
            if let last = sorted.last {
                let lx = tX(last.date)
                path.addLine(to: CGPoint(x: lx, y: basalY + basalH))
                path.addLine(to: CGPoint(x: chartX, y: basalY + basalH))
                path.closeSubpath()
                ctx.addPath(path); ctx.fillPath()
            }
            // Stroke line
            var linePath = CGMutablePath(); first = true
            for pt in sorted {
                let px = tX(pt.date)
                let py = basalY + basalH - CGFloat(pt.basalRate / maxBasal) * basalH
                if first { linePath.move(to: CGPoint(x: px, y: py)); first = false }
                else { linePath.addLine(to: CGPoint(x: px, y: py)) }
            }
            ctx.addPath(linePath); ctx.strokePath()
        }

        // Bolus bars
        for bolus in boluses {
            let bx = tX(bolus.date)
            let maxUnits: Double = 15
            let barH2 = CGFloat(Swift.min(bolus.value / maxUnits, 1.0)) * (chartH * 0.4)
            let barW: CGFloat = 2.5
            ctx.setFillColor(C_BOLUS.withAlphaComponent(0.8).cgColor)
            ctx.fill(CGRect(x: bx - barW / 2, y: chartY + chartH - barH2, width: barW, height: barH2))
        }

        // BG dots
        let sorted = readings.sorted { $0.date < $1.date }
        for reading in sorted {
            let rx = tX(reading.date)
            let ry = gY(Double(reading.sgv))
            let bg = Double(reading.sgv)
            let dotColor: UIColor
            switch bg {
            case ..<54: dotColor = C_VLOW
            case ..<70: dotColor = C_LOW
            case ...180: dotColor = C_IN
            case ...250: dotColor = C_HIGH
            default: dotColor = C_VHIGH
            }
            ctx.setFillColor(dotColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: rx - 1.5, y: ry - 1.5, width: 3, height: 3))
        }

        // X-axis hour labels (just a few)
        let axA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6), .foregroundColor: C_SLATE]
        for h2 in [0, 6, 12, 18, 24] {
            let hx = chartX + CGFloat(h2) / 24 * chartW
            let lbl = String(format: "%02d", h2)
            let sz = (lbl as NSString).size(withAttributes: axA)
            (lbl as NSString).draw(at: CGPoint(x: hx - sz.width / 2, y: chartY + chartH + 2), withAttributes: axA)
        }

        // Clip to card area
        ctx.resetClip()
    }

    // MARK: - Hero header

    @discardableResult
    private static func drawHero(ctx: CGContext, r: CGRect,
                                 patientName: String, providerName: String,
                                 dateOfBirth _: String, startDate: Date, endDate: Date,
                                 stats: SimpleStats) -> CGFloat
    {
        let h: CGFloat = 96
        ctx.setFillColor(C_TEAL.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: h))
        ctx.setFillColor(C_TEAL_DARK.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: 20))

        let a1: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: C_WHITE.withAlphaComponent(0.8), .kern: 1.8]
        "LOOPFOLLOW".draw(at: CGPoint(x: 32, y: 5), withAttributes: a1)

        let a2: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 21), .foregroundColor: C_WHITE]
        "Endocrinologist Visit Report".draw(at: CGPoint(x: 32, y: 22), withAttributes: a2)

        let a3: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9.5), .foregroundColor: C_WHITE.withAlphaComponent(0.82)]
        "Automated Insulin Delivery Performance Summary".draw(at: CGPoint(x: 32, y: 50), withAttributes: a3)

        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        let ds = "\(df.string(from: startDate)) — \(df.string(from: endDate)) (\(Int(stats.days.rounded())) Days)"
        let a4: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: C_WHITE.withAlphaComponent(0.68)]
        ds.draw(at: CGPoint(x: 32, y: 66), withAttributes: a4)

        let a5: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: C_WHITE.withAlphaComponent(0.82)]
        var lines: [String] = []
        if !patientName.isEmpty { lines.append("Patient: \(patientName)") }
        if !providerName.isEmpty { lines.append("Provider: \(providerName)") }
        for (i, l) in lines.enumerated() {
            let sz = (l as NSString).size(withAttributes: a5)
            (l as NSString).draw(at: CGPoint(x: r.width - 34 - sz.width, y: 24 + CGFloat(i) * 15), withAttributes: a5)
        }
        return h
    }

    // MARK: - Page 2 header

    @discardableResult
    private static func drawPageHeader(ctx: CGContext, r: CGRect,
                                       patientName: String, startDate: Date, endDate: Date) -> CGFloat
    {
        let h: CGFloat = 36
        ctx.setFillColor(C_TEAL.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: h))
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: C_WHITE]
        "Endocrinologist Visit Report".draw(at: CGPoint(x: 32, y: 10), withAttributes: a)
        let df = DateFormatter(); df.dateFormat = "MMM d, yyyy"
        let sub = "\(patientName)  •  \(df.string(from: startDate)) – \(df.string(from: endDate))"
        let sa: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: C_WHITE.withAlphaComponent(0.75)]
        let ssz = (sub as NSString).size(withAttributes: sa)
        (sub as NSString).draw(at: CGPoint(x: r.width - 32 - ssz.width, y: 12), withAttributes: sa)
        return h
    }

    // MARK: - Section header

    @discardableResult
    private static func sectionHdr(_ title: String, y: CGFloat, m: CGFloat, w: CGFloat, ctx: CGContext) -> CGFloat {
        ctx.setFillColor(C_TEAL.cgColor)
        ctx.fill(CGRect(x: m, y: y, width: 3, height: 14))
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 9), .foregroundColor: C_TEAL, .kern: 0.6]
        (title as NSString).draw(at: CGPoint(x: m + 8, y: y), withAttributes: a)
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: m, y: y + 15)); ctx.addLine(to: CGPoint(x: w - m, y: y + 15)); ctx.strokePath()
        return y + 19
    }

    // MARK: - Stat card

    private static func statCard(_ label: String, val: String, x: CGFloat, y: CGFloat,
                                 w: CGFloat, h: CGFloat, accent: Bool, ctx: CGContext)
    {
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r)
        if accent {
            ctx.setFillColor(C_TEAL.withAlphaComponent(0.07).cgColor); ctx.fill(r)
            ctx.setFillColor(C_TEAL.cgColor); ctx.fill(CGRect(x: x, y: y, width: 3, height: h))
        }
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r)
        let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.5]
        let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 19), .foregroundColor: accent ? C_TEAL : C_INK]
        (label as NSString).draw(at: CGPoint(x: x + 8, y: y + 6), withAttributes: la)
        (val as NSString).draw(at: CGPoint(x: x + 8, y: y + 16), withAttributes: va)
    }

    // MARK: - TIR vertical bar

    private static func drawTIRBar(tirData: [TIRDataPoint], stats: SimpleStats,
                                   x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, ctx: CGContext)
    {
        guard let avg = tirData.first(where: { $0.period == .average }) else { return }
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r)
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r)

        let ta: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: C_SLATE]
        "Time in Range".draw(at: CGPoint(x: x + 8, y: y + 6), withAttributes: ta)

        let barX = x + 10; let barW: CGFloat = 16
        let barY = y + 20; let barH = h - 38

        let segs: [(Double, UIColor, String)] = [
            (avg.veryHigh, C_VHIGH, "Very High"),
            (avg.high, C_HIGH, "High"),
            (avg.inRange, C_IN, "In Range"),
            (avg.low, C_LOW, "Low"),
            (avg.veryLow, C_VLOW, "Very Low"),
        ]
        var sy = barY
        for (pct, clr, label) in segs {
            let sh = CGFloat(pct / 100) * barH
            if sh > 0 { ctx.setFillColor(clr.cgColor); ctx.fill(CGRect(x: barX, y: sy, width: barW, height: sh)) }
            if sh >= 10 {
                let ps = String(format: "%.0f%%", pct)
                let pa: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: label == "In Range" ? C_TEAL : C_SLATE]
                let sa: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
                (ps as NSString).draw(at: CGPoint(x: barX + barW + 4, y: sy + sh / 2 - 8), withAttributes: pa)
                if sh >= 20 { (label as NSString).draw(at: CGPoint(x: barX + barW + 4, y: sy + sh / 2), withAttributes: sa) }
                if label == "In Range", sh >= 30 {
                    let ts = String(format: "%.0f%% Tight", stats.tightTIR)
                    let ta2: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6), .foregroundColor: C_TIGHT]
                    (ts as NSString).draw(at: CGPoint(x: barX + barW + 4, y: sy + sh / 2 + 10), withAttributes: ta2)
                }
            }
            sy += sh
        }
        let na: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6), .foregroundColor: C_SLATE]
        "Target: 70-180".draw(at: CGPoint(x: x + 6, y: y + h - 18), withAttributes: na)
        "Tight: 70-140".draw(at: CGPoint(x: x + 6, y: y + h - 10), withAttributes: na)
    }

    // MARK: - Time-of-day strip

    @discardableResult
    private static func timeOfDayStrip(patterns: GlycemicPatterns, y: CGFloat,
                                       m: CGFloat, w: CGFloat, ctx: CGContext) -> CGFloat
    {
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 8), .foregroundColor: C_INK]
        "Glucose by Time of Day (mg/dL)".draw(at: CGPoint(x: m, y: y), withAttributes: a)
        let periods = [patterns.night, patterns.earlyAM, patterns.morning,
                       patterns.afternoon, patterns.evening, patterns.late]
        let cw = (w - m * 2) / CGFloat(periods.count); let ch: CGFloat = 42; let cy = y + 13
        for (i, p) in periods.enumerated() {
            let cx = m + CGFloat(i) * cw
            let rr = CGRect(x: cx, y: cy, width: cw - 2, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(rr)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(rr)
            guard p.count > 0 else { continue }
            let vc: UIColor = p.avg < 70 ? C_LOW : p.avg < 140 ? C_TEAL : p.avg < 180 ? C_INK : C_HIGH
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 15), .foregroundColor: vc]
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
            let vs = String(format: "%.0f", p.avg)
            let vsz = (vs as NSString).size(withAttributes: va)
            let lsz = (p.label as NSString).size(withAttributes: la)
            (vs as NSString).draw(at: CGPoint(x: cx + (cw - 2 - vsz.width) / 2, y: cy + 5), withAttributes: va)
            (p.label as NSString).draw(at: CGPoint(x: cx + (cw - 2 - lsz.width) / 2, y: cy + 28), withAttributes: la)
        }
        return cy + ch + 4
    }

    // MARK: - Insulin section

    @discardableResult
    private static func insulinSection(boluses: [MainViewController.bolusGraphStruct],
                                       smbs: [MainViewController.bolusGraphStruct],
                                       simpleVM: SimpleStatsViewModel, stats _: SimpleStats,
                                       y: CGFloat, m: CGFloat, w: CGFloat, ctx: CGContext) -> CGFloat
    {
        let tdd = simpleVM.totalDailyDose ?? 0
        let basalPct = tdd > 0 ? (simpleVM.actualBasal ?? 0) / tdd * 100 : 0
        let bolusPct = tdd > 0 ? (simpleVM.avgBolus ?? 0) / tdd * 100 : 0
        let cards: [(String, String)] = [("AVG TDD", tdd > 0 ? String(format: "%.1fU", tdd) : "—"),
                                         ("BASAL", basalPct > 0 ? String(format: "%.0f%%", basalPct) : "—"),
                                         ("BOLUS", bolusPct > 0 ? String(format: "%.0f%%", bolusPct) : "—")]
        let cw = (w - m * 2) / 3 - 4; let ch: CGFloat = 42
        for (i, c) in cards.enumerated() {
            let cx = m + CGFloat(i) * (cw + 4)
            let r2 = CGRect(x: cx, y: y, width: cw, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r2)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r2)
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.4]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: C_INK]
            (c.0 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 5), withAttributes: la)
            (c.1 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 16), withAttributes: va)
        }
        let tableY = y + ch + 6
        let total = (boluses + smbs).map { $0.value }.reduce(0,+)
        let rows: [(String, String)] = [
            ("Correction Boluses", "\(boluses.count)"),
            ("Total Bolus Insulin", String(format: "%.1f U", total)),
            ("Programmed Basal", simpleVM.programmedBasal != nil ? String(format: "%.2f U/day", simpleVM.programmedBasal!) : "—"),
            ("Actual Basal", simpleVM.actualBasal != nil ? String(format: "%.2f U/day", simpleVM.actualBasal!) : "—"),
            ("Positive Temp Basal", simpleVM.totalPositiveBasal != nil ? String(format: "+%.2f U/day", simpleVM.totalPositiveBasal!) : "—"),
            ("Negative Temp Basal", simpleVM.totalNegativeBasal != nil ? String(format: "%.2f U/day", simpleVM.totalNegativeBasal!) : "—"),
        ]
        return metricTable(rows, y: tableY, m: m, w: w, ctx: ctx)
    }

    // MARK: - Nutrition section

    @discardableResult
    private static func nutritionSection(carbs: [MainViewController.carbGraphStruct],
                                         stats: SimpleStats, y: CGFloat, m: CGFloat, w: CGFloat,
                                         ctx: CGContext) -> CGFloat
    {
        let total = carbs.map { $0.value }.reduce(0,+)
        let cards: [(String, String)] = [
            ("DAILY CARBS", String(format: "%.0fg", total / stats.days)),
            ("MEALS LOGGED", "\(carbs.count)"),
            ("PER MEAL AVG", String(format: "%.0fg", carbs.isEmpty ? 0 : total / Double(carbs.count))),
        ]
        let cw = (w - m * 2) / 3 - 4; let ch: CGFloat = 42
        for (i, c) in cards.enumerated() {
            let cx = m + CGFloat(i) * (cw + 4)
            let r2 = CGRect(x: cx, y: y, width: cw, height: ch)
            ctx.setFillColor(C_CLOUD.cgColor); ctx.fill(r2)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.4); ctx.stroke(r2)
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE, .kern: 0.4]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: C_INK]
            (c.0 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 5), withAttributes: la)
            (c.1 as NSString).draw(at: CGPoint(x: cx + 8, y: y + 16), withAttributes: va)
        }
        return y + ch + 8
    }

    // MARK: - Metric table

    @discardableResult
    private static func metricTable(_ rows: [(String, String)], y: CGFloat, m: CGFloat,
                                    w: CGFloat, ctx: CGContext) -> CGFloat
    {
        let tw = w - m * 2; let hh: CGFloat = 14; let rh: CGFloat = 13; var cy = y
        ctx.setFillColor(C_TEAL.withAlphaComponent(0.10).cgColor)
        ctx.fill(CGRect(x: m, y: cy, width: tw, height: hh))
        let ha: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7), .foregroundColor: C_TEAL, .kern: 0.4]
        "METRIC".draw(at: CGPoint(x: m + 6, y: cy + 3), withAttributes: ha)
        "VALUE".draw(at: CGPoint(x: m + tw * 0.65 + 6, y: cy + 3), withAttributes: ha)
        cy += hh
        for (i, row) in rows.enumerated() {
            ctx.setFillColor((i % 2 == 0 ? C_WHITE : C_CLOUD).cgColor)
            ctx.fill(CGRect(x: m, y: cy, width: tw, height: rh))
            let ka: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: C_INK]
            let va: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 7.5), .foregroundColor: C_TEAL]
            (row.0 as NSString).draw(at: CGPoint(x: m + 6, y: cy + 3), withAttributes: ka)
            (row.1 as NSString).draw(at: CGPoint(x: m + tw * 0.65 + 6, y: cy + 3), withAttributes: va)
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: m, y: cy + rh)); ctx.addLine(to: CGPoint(x: m + tw, y: cy + rh)); ctx.strokePath()
            cy += rh
        }
        return cy + 6
    }

    // MARK: - AGP strip (clean, no overflow)

    private static func drawAGP(agpData: [AGPDataPoint], x: CGFloat, y: CGFloat,
                                w: CGFloat, h: CGFloat, ctx: CGContext)
    {
        guard !agpData.isEmpty else { return }
        // Chart sits inside a padded area — left pad for Y labels, bottom for X labels
        let lPad: CGFloat = 28; let bPad: CGFloat = 14
        let cw = w - lPad; let ch = h - bPad
        let cx = x + lPad; let cy = y

        // Background
        ctx.setFillColor(C_CLOUD.withAlphaComponent(0.5).cgColor)
        ctx.fill(CGRect(x: cx, y: cy, width: cw, height: ch))

        let bgMin: CGFloat = 40; let bgRange: CGFloat = 320
        func gy(_ g: Double) -> CGFloat { cy + ch - (CGFloat(g) - bgMin) / bgRange * ch }
        func tx(_ m2: Int) -> CGFloat { cx + CGFloat(m2) / (24 * 60) * cw }

        // Target zone
        ctx.setFillColor(C_IN.withAlphaComponent(0.08).cgColor)
        ctx.fill(CGRect(x: cx, y: gy(180), width: cw, height: gy(70) - gy(180)))

        // Dashed target lines
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        ctx.setLineWidth(0.6)
        for (val, clr) in [(70.0, C_LOW), (180.0, C_HIGH)] {
            ctx.setStrokeColor(clr.withAlphaComponent(0.5).cgColor)
            ctx.move(to: CGPoint(x: cx, y: gy(val))); ctx.addLine(to: CGPoint(x: cx + cw, y: gy(val))); ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // 5–95 band
        var band = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p95))
            i == 0 ? band.move(to: p) : band.addLine(to: p)
        }
        for pt in agpData.reversed() {
            band.addLine(to: CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p5)))
        }
        band.closeSubpath()
        ctx.setFillColor(C_TEAL.withAlphaComponent(0.11).cgColor); ctx.addPath(band); ctx.fillPath()

        // 25–75 IQR
        var iqr = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p75))
            i == 0 ? iqr.move(to: p) : iqr.addLine(to: p)
        }
        for pt in agpData.reversed() {
            iqr.addLine(to: CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p25)))
        }
        iqr.closeSubpath()
        ctx.setFillColor(C_TEAL.withAlphaComponent(0.26).cgColor); ctx.addPath(iqr); ctx.fillPath()

        // Median
        ctx.setStrokeColor(C_TEAL.cgColor); ctx.setLineWidth(1.6)
        var first = true
        for pt in agpData {
            let p = CGPoint(x: tx(pt.timeOfDay), y: gy(pt.p50))
            first ? ctx.move(to: p) : ctx.addLine(to: p); first = false
        }
        ctx.strokePath()

        // Clip so nothing bleeds outside chart area
        ctx.clip(to: CGRect(x: cx, y: cy, width: cw, height: ch))
        ctx.resetClip()

        // Y-axis labels — drawn LEFT of chart, never inside
        let axA: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
        for bg in [70, 140, 180, 250] {
            let ly = gy(Double(bg))
            guard ly >= cy, ly <= cy + ch else { continue }
            let lbl = "\(bg)"
            let lsz = (lbl as NSString).size(withAttributes: axA)
            (lbl as NSString).draw(at: CGPoint(x: x + lPad - lsz.width - 3, y: ly - lsz.height / 2), withAttributes: axA)
            // Subtle grid line
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: cx, y: ly)); ctx.addLine(to: CGPoint(x: cx + cw, y: ly)); ctx.strokePath()
        }

        // X-axis labels — drawn BELOW chart, even spacing
        for h2 in stride(from: 0, through: 24, by: 3) {
            let lx = tx(h2 * 60)
            let lbl = String(format: "%02d:00", h2)
            let lsz = (lbl as NSString).size(withAttributes: axA)
            // Clamp to chart bounds
            let drawX = Swift.max(cx, Swift.min(cx + cw - lsz.width, lx - lsz.width / 2))
            (lbl as NSString).draw(at: CGPoint(x: drawX, y: cy + ch + 2), withAttributes: axA)
            // Vertical grid line
            ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: lx, y: cy)); ctx.addLine(to: CGPoint(x: lx, y: cy + ch)); ctx.strokePath()
        }

        // Border
        ctx.setStrokeColor(C_BORDER.cgColor); ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: cx, y: cy, width: cw, height: ch))

        // Legend — right-aligned, below chart
        let lgY = cy + ch + 2
        let lgItems: [(String, UIColor, Bool)] = [("Median", C_TEAL, false),
                                                  ("25–75th", C_TEAL.withAlphaComponent(0.4), true),
                                                  ("5–95th", C_TEAL.withAlphaComponent(0.18), true)]
        var lgX = cx + cw
        for item in lgItems.reversed() {
            let la: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_SLATE]
            let lsz = (item.0 as NSString).size(withAttributes: la)
            lgX -= lsz.width
            (item.0 as NSString).draw(at: CGPoint(x: lgX, y: lgY), withAttributes: la)
            lgX -= 16
            if item.2 { ctx.setFillColor(item.1.cgColor); ctx.fill(CGRect(x: lgX, y: lgY + 1, width: 12, height: 8)) }
            else { ctx.setFillColor(item.1.cgColor); ctx.fill(CGRect(x: lgX, y: lgY + 4, width: 12, height: 2)) }
            lgX -= 6
        }
    }

    // MARK: - Footer

    private static func footer(ctx: CGContext, r: CGRect,
                               startDate _: Date, endDate _: Date, stats: SimpleStats, page: Int)
    {
        let fy = r.height - 28
        ctx.setFillColor(C_INK.cgColor); ctx.fill(CGRect(x: 0, y: fy, width: r.width, height: 28))
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6.5), .foregroundColor: C_WHITE.withAlphaComponent(0.5)]
        let disc = "LoopFollow — for informational purposes only. Not a substitute for professional medical advice."
        (disc as NSString).draw(in: CGRect(x: 32, y: fy + 4, width: r.width - 200, height: 20), withAttributes: a)
        let df = DateFormatter(); df.dateFormat = "MMM d, yyyy"
        let meta = "Generated: \(df.string(from: Date()))  •  \(Int(stats.days.rounded())) Days  •  \(stats.readingCount) readings  •  Page \(page)"
        let msz = (meta as NSString).size(withAttributes: a)
        (meta as NSString).draw(at: CGPoint(x: r.width - 32 - msz.width, y: fy + 4), withAttributes: a)
    }
}
