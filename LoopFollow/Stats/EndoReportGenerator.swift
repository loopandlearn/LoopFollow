// LoopFollow
// EndoReportGenerator.swift

import PDFKit
import SwiftUI
import UIKit

enum EndoReportGenerator {
    // MARK: - Public entry point

    /// Generates a PDF and returns the file URL, or throws on failure.
    static func generate(
        patientName: String,
        dateOfBirth: String,
        providerName: String,
        startDate: Date,
        endDate: Date,
        dataService: StatsDataService
    ) throws -> URL {
        let bgData = dataService.getBGData()
        guard !bgData.isEmpty else {
            throw ReportError.noData
        }

        let agpData = AGPCalculator.calculate(bgData: bgData)
        let tirData = TIRCalculator.calculate(bgData: bgData)
        let stats = SimpleStats(bgData: bgData, dataService: dataService)

        let pageRect = CGRect(origin: .zero, size: CGSize(width: 612, height: 792)) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EndoReport_\(Int(Date().timeIntervalSince1970)).pdf")

        let data = renderer.pdfData { ctx in
            // ── Page 1: Summary + AGP ──────────────────────────────────────
            ctx.beginPage()
            var cursor = drawHeader(
                ctx: ctx.cgContext,
                pageRect: pageRect,
                patientName: patientName,
                dateOfBirth: dateOfBirth,
                providerName: providerName,
                startDate: startDate,
                endDate: endDate
            )

            cursor = drawSectionTitle("Key Metrics", y: cursor, in: pageRect, ctx: ctx.cgContext)
            cursor = drawKeyMetrics(stats: stats, y: cursor, in: pageRect, ctx: ctx.cgContext)

            cursor = drawSectionTitle("Time in Range", y: cursor, in: pageRect, ctx: ctx.cgContext)
            cursor = drawTIRBar(tirData: tirData, y: cursor, in: pageRect, ctx: ctx.cgContext)
            cursor = drawTIRTable(tirData: tirData, y: cursor, in: pageRect, ctx: ctx.cgContext)

            cursor = drawSectionTitle("Ambulatory Glucose Profile (AGP)", y: cursor, in: pageRect, ctx: ctx.cgContext)
            cursor = drawAGPChart(agpData: agpData, y: cursor, in: pageRect, ctx: ctx.cgContext)
            drawFooter(ctx: ctx.cgContext, pageRect: pageRect, page: 1)

            // ── Page 2: Daily stats + Insulin/Carbs ───────────────────────
            ctx.beginPage()
            var cursor2 = drawPageContinuationHeader(ctx: ctx.cgContext, pageRect: pageRect,
                                                     patientName: patientName,
                                                     startDate: startDate, endDate: endDate)

            cursor2 = drawSectionTitle("Daily Glucose Summary", y: cursor2, in: pageRect, ctx: ctx.cgContext)
            cursor2 = drawDailyTable(bgData: bgData, y: cursor2, in: pageRect, ctx: ctx.cgContext)

            // Insulin & carbs if available
            let boluses = dataService.getBolusData()
            let smbs = dataService.getSMBData()
            let carbs = dataService.getCarbData()
            if !boluses.isEmpty || !smbs.isEmpty || !carbs.isEmpty {
                cursor2 = drawSectionTitle("Insulin & Carbohydrate Summary",
                                           y: cursor2, in: pageRect, ctx: ctx.cgContext)
                cursor2 = drawInsulinCarbSummary(boluses: boluses, smbs: smbs, carbs: carbs,
                                                 stats: stats, y: cursor2,
                                                 in: pageRect, ctx: ctx.cgContext)
            }

            drawFooter(ctx: ctx.cgContext, pageRect: pageRect, page: 2)
        }

        try data.write(to: url)
        return url
    }

    // MARK: - Errors

    enum ReportError: LocalizedError {
        case noData
        var errorDescription: String? {
            switch self {
            case .noData: return "No CGM data available for the selected date range."
            }
        }
    }

    // MARK: - Computed stats helper

    struct SimpleStats {
        let avg: Double
        let stdDev: Double
        let cv: Double
        let eA1C: Double
        let min: Double
        let max: Double
        let sensorPct: Double
        let readingCount: Int

        init(bgData: [ShareGlucoseData], dataService: StatsDataService) {
            let vals = bgData.map { Double($0.sgv) }
            let n = Double(vals.count)
            let mean = vals.reduce(0, +) / n
            let variance = vals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n
            avg = mean
            stdDev = sqrt(variance)
            cv = stdDev / mean * 100
            eA1C = (mean + 46.7) / 28.7
            min = vals.min() ?? 0
            max = vals.max() ?? 0
            readingCount = vals.count

            let days = Swift.max(dataService.endDate.timeIntervalSince1970 - dataService.startDate.timeIntervalSince1970, 86400) / 86400
            let expected = days * 288
            sensorPct = Swift.min(Double(vals.count) / expected * 100, 100)
        }
    }

    // MARK: - Layout constants

    private static let margin: CGFloat = 36
    private static let bodyFont = UIFont.systemFont(ofSize: 9)
    private static let labelFont = UIFont.systemFont(ofSize: 8)
    private static let boldFont = UIFont.boldSystemFont(ofSize: 9)
    private static let titleFont = UIFont.boldSystemFont(ofSize: 11)
    private static let sectionFont = UIFont.boldSystemFont(ofSize: 10)

    private static let colorVeryLow = UIColor(red: 0.957, green: 0.263, blue: 0.212, alpha: 1)
    private static let colorLow = UIColor(red: 1.000, green: 0.596, blue: 0.000, alpha: 1)
    private static let colorInRange = UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1)
    private static let colorHigh = UIColor(red: 1.000, green: 0.757, blue: 0.027, alpha: 1)
    private static let colorVeryHigh = UIColor(red: 1.000, green: 0.341, blue: 0.133, alpha: 1)
    private static let colorBlue = UIColor(red: 0.102, green: 0.451, blue: 0.933, alpha: 1)
    private static let colorDark = UIColor(red: 0.110, green: 0.169, blue: 0.227, alpha: 1)
    private static let colorLightGray = UIColor(red: 0.957, green: 0.961, blue: 0.976, alpha: 1)
    private static let colorBorder = UIColor(red: 0.867, green: 0.890, blue: 0.925, alpha: 1)

    // MARK: - Header / Footer

    @discardableResult
    private static func drawHeader(
        ctx: CGContext,
        pageRect: CGRect,
        patientName: String,
        dateOfBirth: String,
        providerName: String,
        startDate: Date,
        endDate: Date
    ) -> CGFloat {
        let headerH: CGFloat = 52
        ctx.setFillColor(colorDark.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: headerH))

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.white,
        ]
        "Continuous Glucose Monitor Report".draw(at: CGPoint(x: margin, y: 10), withAttributes: titleAttrs)

        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        let rangeStr = "\(df.string(from: startDate)) – \(df.string(from: endDate))"
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor(white: 0.8, alpha: 1),
        ]
        let rangeSize = (rangeStr as NSString).size(withAttributes: subAttrs)
        (rangeStr as NSString).draw(
            at: CGPoint(x: pageRect.width - margin - rangeSize.width, y: 12),
            withAttributes: subAttrs
        )

        // Patient info bar
        let infoY: CGFloat = 28
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: UIColor(white: 0.75, alpha: 1),
        ]
        "Patient: \(patientName)".draw(at: CGPoint(x: margin, y: infoY), withAttributes: infoAttrs)
        if !dateOfBirth.isEmpty {
            "DOB: \(dateOfBirth)".draw(at: CGPoint(x: margin + 180, y: infoY), withAttributes: infoAttrs)
        }
        if !providerName.isEmpty {
            let provStr = "Provider: \(providerName)"
            let provSize = (provStr as NSString).size(withAttributes: infoAttrs)
            (provStr as NSString).draw(
                at: CGPoint(x: pageRect.width - margin - provSize.width, y: infoY),
                withAttributes: infoAttrs
            )
        }

        return headerH + 12
    }

    @discardableResult
    private static func drawPageContinuationHeader(
        ctx: CGContext, pageRect: CGRect,
        patientName: String, startDate _: Date, endDate _: Date
    ) -> CGFloat {
        let headerH: CGFloat = 32
        ctx.setFillColor(colorDark.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: headerH))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.white,
        ]
        "CGM Report — \(patientName)".draw(at: CGPoint(x: margin, y: 9), withAttributes: attrs)
        return headerH + 12
    }

    private static func drawFooter(ctx: CGContext, pageRect: CGRect, page: Int) {
        let footerY = pageRect.height - 28
        ctx.setFillColor(colorLightGray.cgColor)
        ctx.fill(CGRect(x: 0, y: footerY, width: pageRect.width, height: 28))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        "LoopFollow CGM Report  |  For clinical use only  |  Targets 70–180 mg/dL"
            .draw(at: CGPoint(x: margin, y: footerY + 8), withAttributes: attrs)

        let pageStr = "Page \(page)"
        let pageSize = (pageStr as NSString).size(withAttributes: attrs)
        (pageStr as NSString).draw(
            at: CGPoint(x: pageRect.width - margin - pageSize.width, y: footerY + 8),
            withAttributes: attrs
        )
    }

    // MARK: - Section title

    @discardableResult
    private static func drawSectionTitle(_ title: String, y: CGFloat, in pageRect: CGRect, ctx: CGContext) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: colorBlue,
        ]
        (title.uppercased() as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)

        let lineY = y + 14
        ctx.setStrokeColor(colorBorder.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: margin, y: lineY))
        ctx.addLine(to: CGPoint(x: pageRect.width - margin, y: lineY))
        ctx.strokePath()

        return lineY + 8
    }

    // MARK: - Key metrics cards

    @discardableResult
    private static func drawKeyMetrics(stats: SimpleStats, y: CGFloat, in pageRect: CGRect, ctx: CGContext) -> CGFloat {
        let units = Storage.shared.units.value
        let isMMOL = units == "mmol/L"

        func fmtGlucose(_ v: Double) -> String {
            isMMOL ? String(format: "%.1f", v * 0.0555) : String(format: "%.0f", v)
        }

        let cards: [(String, String, String)] = [
            ("eA1C", String(format: "%.1f%%", stats.eA1C), "Estimated A1C"),
            ("TIR", {
                // grab from TIR calculator average
                let t = TIRCalculator.calculate(bgData: []) // placeholder — we draw this separately
                return "—"
            }(), "70–180 mg/dL"),
            ("Avg Glucose", fmtGlucose(stats.avg), units),
            ("CV", String(format: "%.1f%%", stats.cv), "SD \(fmtGlucose(stats.stdDev))"),
            ("Sensor Active", String(format: "%.0f%%", stats.sensorPct), "\(stats.readingCount) readings"),
        ]

        let cardW = (pageRect.width - margin * 2) / CGFloat(cards.count)
        let cardH: CGFloat = 52
        let startX = margin

        for (i, card) in cards.enumerated() {
            let cardX = startX + CGFloat(i) * cardW
            let rect = CGRect(x: cardX, y: y, width: cardW - 4, height: cardH)

            // Background
            ctx.setFillColor(colorLightGray.cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(colorBorder.cgColor)
            ctx.setLineWidth(0.5)
            ctx.stroke(rect)

            // Value
            let valAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 17),
                .foregroundColor: colorDark,
            ]
            let valSize = (card.1 as NSString).size(withAttributes: valAttrs)
            let valX = cardX + (cardW - 4 - valSize.width) / 2
            (card.1 as NSString).draw(at: CGPoint(x: valX, y: y + 8), withAttributes: valAttrs)

            // Label
            let lblAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7.5),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let lblSize = (card.0 as NSString).size(withAttributes: lblAttrs)
            (card.0 as NSString).draw(
                at: CGPoint(x: cardX + (cardW - 4 - lblSize.width) / 2, y: y + 28),
                withAttributes: lblAttrs
            )

            let subSize = (card.2 as NSString).size(withAttributes: lblAttrs)
            (card.2 as NSString).draw(
                at: CGPoint(x: cardX + (cardW - 4 - subSize.width) / 2, y: y + 39),
                withAttributes: lblAttrs
            )
        }

        return y + cardH + 12
    }

    // MARK: - TIR bar

    @discardableResult
    private static func drawTIRBar(tirData: [TIRDataPoint], y: CGFloat, in pageRect: CGRect, ctx: CGContext) -> CGFloat {
        guard let avg = tirData.first(where: { $0.period == .average }) else { return y }

        let barW = pageRect.width - margin * 2
        let barH: CGFloat = 20
        var x = margin

        let segments: [(CGFloat, UIColor)] = [
            (CGFloat(avg.veryLow / 100) * barW, colorVeryLow),
            (CGFloat(avg.low / 100) * barW, colorLow),
            (CGFloat(avg.inRange / 100) * barW, colorInRange),
            (CGFloat(avg.high / 100) * barW, colorHigh),
            (CGFloat(avg.veryHigh / 100) * barW, colorVeryHigh),
        ]

        for (w, clr) in segments {
            if w > 0 {
                ctx.setFillColor(clr.cgColor)
                ctx.fill(CGRect(x: x, y: y, width: w, height: barH))
            }
            x += w
        }

        // Labels inside bar
        x = margin
        let pcts = [avg.veryLow, avg.low, avg.inRange, avg.high, avg.veryHigh]
        let clrs = [colorVeryLow, colorLow, colorInRange, colorHigh, colorVeryHigh]
        for (i, pct) in pcts.enumerated() {
            let w = CGFloat(pct / 100) * barW
            if pct >= 5 {
                let pctStr = String(format: "%.1f%%", pct)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 8),
                    .foregroundColor: UIColor.white,
                ]
                let sz = (pctStr as NSString).size(withAttributes: attrs)
                (pctStr as NSString).draw(
                    at: CGPoint(x: x + (w - sz.width) / 2, y: y + (barH - sz.height) / 2),
                    withAttributes: attrs
                )
            }
            x += w
        }

        // Legend
        let legendY = y + barH + 4
        let legendItems: [(String, UIColor)] = [
            ("Very Low <54", colorVeryLow),
            ("Low 54-69", colorLow),
            ("In Range 70-180", colorInRange),
            ("High 181-250", colorHigh),
            ("Very High >250", colorVeryHigh),
        ]
        let itemW = barW / CGFloat(legendItems.count)
        for (i, item) in legendItems.enumerated() {
            let ix = margin + CGFloat(i) * itemW
            ctx.setFillColor(item.1.cgColor)
            ctx.fill(CGRect(x: ix, y: legendY, width: 8, height: 8))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            (item.0 as NSString).draw(at: CGPoint(x: ix + 10, y: legendY), withAttributes: attrs)
        }

        return legendY + 16
    }

    // MARK: - TIR table

    @discardableResult
    private static func drawTIRTable(tirData: [TIRDataPoint], y: CGFloat, in _: CGRect, ctx: CGContext) -> CGFloat {
        let cols: [CGFloat] = [100, 100, 70, 80, 70]
        let headers = ["Zone", "Range", "Your %", "ADA Target", "Status"]
        let rows: [(String, String, Double, String, Bool)] = [
            ("Very Low", "< 54 mg/dL", tirData.first(where: { $0.period == .average })?.veryLow ?? 0, "< 1%", (tirData.first(where: { $0.period == .average })?.veryLow ?? 99) < 1),
            ("Low", "54–69 mg/dL", tirData.first(where: { $0.period == .average })?.low ?? 0, "< 4%", (tirData.first(where: { $0.period == .average })?.low ?? 99) < 4),
            ("In Range", "70–180 mg/dL", tirData.first(where: { $0.period == .average })?.inRange ?? 0, "> 70%", (tirData.first(where: { $0.period == .average })?.inRange ?? 0) >= 70),
            ("High", "181–250 mg/dL", tirData.first(where: { $0.period == .average })?.high ?? 0, "< 25%", (tirData.first(where: { $0.period == .average })?.high ?? 99) < 25),
            ("Very High", "> 250 mg/dL", tirData.first(where: { $0.period == .average })?.veryHigh ?? 0, "< 5%", (tirData.first(where: { $0.period == .average })?.veryHigh ?? 99) < 5),
        ]
        let rowColors = [colorVeryLow, colorLow, colorInRange, colorHigh, colorVeryHigh]

        let rowH: CGFloat = 16
        var curY = y
        var curX = margin

        // Header row
        ctx.setFillColor(colorDark.cgColor)
        let totalW = cols.reduce(0, +)
        ctx.fill(CGRect(x: margin, y: curY, width: totalW, height: rowH))
        for (i, h) in headers.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 8),
                .foregroundColor: UIColor.white,
            ]
            (h as NSString).draw(at: CGPoint(x: curX + 4, y: curY + 4), withAttributes: attrs)
            curX += cols[i]
        }
        curY += rowH

        // Data rows
        for (ri, row) in rows.enumerated() {
            ctx.setFillColor((ri % 2 == 0 ? UIColor.white : colorLightGray).cgColor)
            ctx.fill(CGRect(x: margin, y: curY, width: totalW, height: rowH))

            // Zone color swatch in first cell
            ctx.setFillColor(rowColors[ri].cgColor)
            ctx.fill(CGRect(x: margin, y: curY, width: cols[0], height: rowH))

            let cells = [row.0, row.1, String(format: "%.1f%%", row.2), row.3, row.4 ? "✓" : "↑"]
            curX = margin
            for (ci, cell) in cells.enumerated() {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: ci == 0 ? UIFont.boldSystemFont(ofSize: 8) : UIFont.systemFont(ofSize: 8),
                    .foregroundColor: ci == 0 ? UIColor.white : colorDark,
                ]
                (cell as NSString).draw(at: CGPoint(x: curX + 4, y: curY + 4), withAttributes: attrs)
                curX += cols[ci]
            }

            // Border
            ctx.setStrokeColor(colorBorder.cgColor)
            ctx.setLineWidth(0.3)
            ctx.stroke(CGRect(x: margin, y: curY, width: totalW, height: rowH))
            curY += rowH
        }

        return curY + 12
    }

    // MARK: - AGP chart (drawn natively with Core Graphics)

    @discardableResult
    private static func drawAGPChart(agpData: [AGPDataPoint], y: CGFloat, in pageRect: CGRect, ctx: CGContext) -> CGFloat {
        guard !agpData.isEmpty else { return y }

        let chartW: CGFloat = pageRect.width - margin * 2
        let chartH: CGFloat = 140
        let chartX: CGFloat = margin
        let chartY: CGFloat = y

        // Background
        ctx.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor)
        ctx.fill(CGRect(x: chartX, y: chartY, width: chartW, height: chartH))

        // Target zones
        let yRange: CGFloat = 350 // 40–400
        let yMin: CGFloat = 40
        func glucoseToY(_ g: Double) -> CGFloat {
            chartY + chartH - (CGFloat(g) - yMin) / yRange * chartH
        }
        func timeToX(_ minutes: Int) -> CGFloat {
            chartX + CGFloat(minutes) / (24 * 60) * chartW
        }

        // Very low zone
        ctx.setFillColor(colorVeryLow.withAlphaComponent(0.08).cgColor)
        ctx.fill(CGRect(x: chartX, y: glucoseToY(54), width: chartW, height: glucoseToY(40) - glucoseToY(54)))

        // Low zone
        ctx.setFillColor(colorLow.withAlphaComponent(0.08).cgColor)
        ctx.fill(CGRect(x: chartX, y: glucoseToY(70), width: chartW, height: glucoseToY(54) - glucoseToY(70)))

        // High zone
        ctx.setFillColor(colorHigh.withAlphaComponent(0.08).cgColor)
        ctx.fill(CGRect(x: chartX, y: glucoseToY(250), width: chartW, height: glucoseToY(180) - glucoseToY(250)))

        // Target lines
        ctx.setStrokeColor(colorLow.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(0.8)
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        ctx.move(to: CGPoint(x: chartX, y: glucoseToY(70)))
        ctx.addLine(to: CGPoint(x: chartX + chartW, y: glucoseToY(70)))
        ctx.strokePath()

        ctx.setStrokeColor(colorHigh.withAlphaComponent(0.6).cgColor)
        ctx.move(to: CGPoint(x: chartX, y: glucoseToY(180)))
        ctx.addLine(to: CGPoint(x: chartX + chartW, y: glucoseToY(180)))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // 5–95 band
        let p5Path = CGMutablePath()
        let p95Path = CGMutablePath()
        var bandPath = CGMutablePath()

        for (i, pt) in agpData.enumerated() {
            let x = timeToX(pt.timeOfDay)
            let y5 = glucoseToY(pt.p5)
            let y95 = glucoseToY(pt.p95)
            if i == 0 {
                p5Path.move(to: CGPoint(x: x, y: y5))
                p95Path.move(to: CGPoint(x: x, y: y95))
                bandPath.move(to: CGPoint(x: x, y: y95))
            } else {
                p5Path.addLine(to: CGPoint(x: x, y: y5))
                p95Path.addLine(to: CGPoint(x: x, y: y95))
                bandPath.addLine(to: CGPoint(x: x, y: y95))
            }
        }
        // Close band with p5 reversed
        for pt in agpData.reversed() {
            bandPath.addLine(to: CGPoint(x: timeToX(pt.timeOfDay), y: glucoseToY(pt.p5)))
        }
        bandPath.closeSubpath()
        ctx.setFillColor(colorBlue.withAlphaComponent(0.12).cgColor)
        ctx.addPath(bandPath)
        ctx.fillPath()

        // 25–75 band
        var iqrPath = CGMutablePath()
        for (i, pt) in agpData.enumerated() {
            let x = timeToX(pt.timeOfDay)
            if i == 0 { iqrPath.move(to: CGPoint(x: x, y: glucoseToY(pt.p75))) }
            else { iqrPath.addLine(to: CGPoint(x: x, y: glucoseToY(pt.p75))) }
        }
        for pt in agpData.reversed() {
            iqrPath.addLine(to: CGPoint(x: timeToX(pt.timeOfDay), y: glucoseToY(pt.p25)))
        }
        iqrPath.closeSubpath()
        ctx.setFillColor(colorBlue.withAlphaComponent(0.25).cgColor)
        ctx.addPath(iqrPath)
        ctx.fillPath()

        // Median line
        ctx.setStrokeColor(colorBlue.cgColor)
        ctx.setLineWidth(1.8)
        var first = true
        for pt in agpData {
            let pt2D = CGPoint(x: timeToX(pt.timeOfDay), y: glucoseToY(pt.p50))
            if first { ctx.move(to: pt2D); first = false }
            else { ctx.addLine(to: pt2D) }
        }
        ctx.strokePath()

        // X axis labels
        let axisAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: UIColor.secondaryLabel,
        ]
        for h in stride(from: 0, through: 24, by: 3) {
            let lbl = String(format: "%02d:00", h)
            let lx = timeToX(h * 60)
            let lsize = (lbl as NSString).size(withAttributes: axisAttrs)
            (lbl as NSString).draw(at: CGPoint(x: lx - lsize.width / 2, y: chartY + chartH + 2), withAttributes: axisAttrs)

            // Vertical grid line
            ctx.setStrokeColor(colorBorder.cgColor)
            ctx.setLineWidth(0.3)
            ctx.move(to: CGPoint(x: lx, y: chartY))
            ctx.addLine(to: CGPoint(x: lx, y: chartY + chartH))
            ctx.strokePath()
        }

        // Y axis labels
        for bg in [54, 70, 140, 180, 250, 350] {
            let ly = glucoseToY(Double(bg))
            let lbl = "\(bg)"
            let lsz = (lbl as NSString).size(withAttributes: axisAttrs)
            (lbl as NSString).draw(at: CGPoint(x: chartX - lsz.width - 3, y: ly - lsz.height / 2), withAttributes: axisAttrs)
        }

        // Border
        ctx.setStrokeColor(colorBorder.cgColor)
        ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: chartX, y: chartY, width: chartW, height: chartH))

        // Legend
        let lgY = chartY + chartH + 12
        let legendItems: [(String, UIColor, Bool)] = [
            ("Median", colorBlue, false),
            ("25–75th %ile", colorBlue.withAlphaComponent(0.4), true),
            ("5–95th %ile", colorBlue.withAlphaComponent(0.18), true),
        ]
        var lgX = chartX
        for item in legendItems {
            ctx.setFillColor(item.1.cgColor)
            ctx.fill(CGRect(x: lgX, y: lgY, width: item.2 ? 14 : 20, height: item.2 ? 8 : 2.5))
            if !item.2 {
                // line for median
                ctx.setFillColor(item.1.cgColor)
                ctx.fill(CGRect(x: lgX, y: lgY + 2, width: 20, height: 2))
            }
            let lgAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7.5),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let lsz = (item.0 as NSString).size(withAttributes: lgAttrs)
            (item.0 as NSString).draw(at: CGPoint(x: lgX + (item.2 ? 18 : 24), y: lgY), withAttributes: lgAttrs)
            lgX += lsz.width + (item.2 ? 18 : 24) + 16
        }

        return lgY + 20
    }

    // MARK: - Daily summary table

    @discardableResult
    private static func drawDailyTable(bgData: [ShareGlucoseData], y: CGFloat, in _: CGRect, ctx: CGContext) -> CGFloat {
        // Group by day
        let calendar = dateTimeUtils.displayCalendar()
        var byDay: [String: [Double]] = [:]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for r in bgData {
            let d = df.string(from: Date(timeIntervalSince1970: r.date))
            byDay[d, default: []].append(Double(r.sgv))
        }

        let cols: [CGFloat] = [90, 60, 50, 50, 55, 60, 60]
        let headers = ["Date", "Avg", "SD", "Min", "Max", "TIR %", "Readings"]
        let totalW = cols.reduce(0, +)
        let rowH: CGFloat = 14
        var curY = y
        var curX = margin

        // Header
        ctx.setFillColor(colorDark.cgColor)
        ctx.fill(CGRect(x: margin, y: curY, width: totalW, height: rowH))
        for (i, h) in headers.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 7.5),
                .foregroundColor: UIColor.white,
            ]
            (h as NSString).draw(at: CGPoint(x: curX + 3, y: curY + 3), withAttributes: attrs)
            curX += cols[i]
        }
        curY += rowH

        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 7.5),
            .foregroundColor: colorDark,
        ]
        let df2 = DateFormatter()
        df2.dateFormat = "EEE MMM d"

        for (ri, day) in byDay.keys.sorted().enumerated() {
            let vals = byDay[day]!
            let n = Double(vals.count)
            let mean = vals.reduce(0, +) / n
            let sd = sqrt(vals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / n)
            let tir = vals.filter { $0 >= 70 && $0 <= 180 }.count
            let tirPct = Double(tir) / n * 100

            let date = df.date(from: day) ?? Date()
            let cells = [
                df2.string(from: date),
                String(format: "%.0f", mean),
                String(format: "%.0f", sd),
                String(format: "%.0f", vals.min() ?? 0),
                String(format: "%.0f", vals.max() ?? 0),
                String(format: "%.0f%%", tirPct),
                "\(vals.count)",
            ]

            ctx.setFillColor((ri % 2 == 0 ? UIColor.white : colorLightGray).cgColor)
            ctx.fill(CGRect(x: margin, y: curY, width: totalW, height: rowH))

            curX = margin
            for (ci, cell) in cells.enumerated() {
                (cell as NSString).draw(at: CGPoint(x: curX + 3, y: curY + 3), withAttributes: dayAttrs)
                curX += cols[ci]
            }
            ctx.setStrokeColor(colorBorder.cgColor)
            ctx.setLineWidth(0.3)
            ctx.stroke(CGRect(x: margin, y: curY, width: totalW, height: rowH))
            curY += rowH
        }

        return curY + 14
    }

    // MARK: - Insulin & carb summary

    @discardableResult
    private static func drawInsulinCarbSummary(
        boluses: [MainViewController.bolusGraphStruct],
        smbs: [MainViewController.bolusGraphStruct],
        carbs: [MainViewController.carbGraphStruct],
        stats: SimpleStats,
        y: CGFloat,
        in pageRect: CGRect,
        ctx: CGContext
    ) -> CGFloat {
        let days = max(stats.sensorPct / 100 * 14, 1)
        let totalBolus = boluses.map { $0.value }.reduce(0, +)
            + smbs.map { $0.value }.reduce(0, +)
        let totalCarbs = carbs.map { $0.value }.reduce(0, +)

        let cards: [(String, String, String)] = [
            ("Avg Daily Bolus", String(format: "%.1f U", totalBolus / days), "Total \(String(format: "%.1f", totalBolus)) U"),
            ("Bolus Count", "\(boluses.count + smbs.count)", "Over report period"),
            ("Avg Daily Carbs", String(format: "%.0f g", totalCarbs / days), "Total \(String(format: "%.0f", totalCarbs)) g"),
            ("Carb Entries", "\(carbs.count)", "Logged entries"),
        ]

        let cardW = (pageRect.width - margin * 2) / CGFloat(cards.count)
        let cardH: CGFloat = 48

        for (i, card) in cards.enumerated() {
            let cardX = margin + CGFloat(i) * cardW
            let rect = CGRect(x: cardX, y: y, width: cardW - 4, height: cardH)
            ctx.setFillColor(colorLightGray.cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(colorBorder.cgColor)
            ctx.setLineWidth(0.5)
            ctx.stroke(rect)

            let valAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: colorDark,
            ]
            let valSz = (card.1 as NSString).size(withAttributes: valAttrs)
            (card.1 as NSString).draw(at: CGPoint(x: cardX + (cardW - 4 - valSz.width) / 2, y: y + 6), withAttributes: valAttrs)

            let lblAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 7.5),
                .foregroundColor: UIColor.secondaryLabel,
            ]
            let lsz = (card.0 as NSString).size(withAttributes: lblAttrs)
            (card.0 as NSString).draw(at: CGPoint(x: cardX + (cardW - 4 - lsz.width) / 2, y: y + 24), withAttributes: lblAttrs)

            let ssz = (card.2 as NSString).size(withAttributes: lblAttrs)
            (card.2 as NSString).draw(at: CGPoint(x: cardX + (cardW - 4 - ssz.width) / 2, y: y + 34), withAttributes: lblAttrs)
        }

        return y + cardH + 14
    }
}
