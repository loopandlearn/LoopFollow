// LoopFollow
// Chart.swift

import Charts
import Foundation

final class OverrideFillFormatter: FillFormatter {
    func getFillLinePosition(dataSet: Charts.LineChartDataSetProtocol, dataProvider _: Charts.LineChartDataProvider) -> CGFloat {
        return CGFloat(dataSet.entryForIndex(0)!.y)
        // return 375
    }
}

final class basalFillFormatter: FillFormatter {
    func getFillLinePosition(dataSet _: Charts.LineChartDataSetProtocol, dataProvider _: Charts.LineChartDataProvider) -> CGFloat {
        return 0
    }
}

final class ChartXValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        let dateFormatter = DateFormatter()
        // let timezoneOffset = TimeZone.current.secondsFromGMT()
        // let epochTimezoneOffset = value + Double(timezoneOffset)
        if dateTimeUtils.is24Hour() {
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
        }

        if Storage.shared.graphTimeZoneEnabled.value,
           let tz = TimeZone(identifier: Storage.shared.graphTimeZoneIdentifier.value)
        {
            dateFormatter.timeZone = tz
        }

        // let date = Date(timeIntervalSince1970: epochTimezoneOffset)
        let date = Date(timeIntervalSince1970: value)
        let formattedDate = dateFormatter.string(from: date)

        return formattedDate
    }
}

final class ChartYDataValueFormatter: ValueFormatter {
    func stringForValue(_: Double, entry: ChartDataEntry, dataSetIndex _: Int, viewPortHandler _: ViewPortHandler?) -> String {
        guard let text = entry.data as? String else { return "" }
        // Treatment entries store "label\r\rpillText" — extract only the label portion.
        if let range = text.range(of: "\r\r") {
            return String(text[..<range.lowerBound])
        }
        return text
    }
}

final class ChartYOverrideValueFormatter: ValueFormatter {
    func stringForValue(_: Double, entry: ChartDataEntry, dataSetIndex _: Int, viewPortHandler _: ViewPortHandler?) -> String {
        if entry.data != nil {
            return entry.data as? String ?? ""
        } else {
            return ""
        }
    }
}

final class ChartYMMOLValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        return Localizer.toDisplayUnits(String(value))
    }
}

class PillMarker: MarkerImage {
    private(set) var color: UIColor
    private(set) var font: UIFont
    private(set) var textColor: UIColor
    private var labelText: String = ""
    private var attrs: [NSAttributedString.Key: AnyObject]!

    static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.minute, .second]
        f.unitsStyle = .short
        return f
    }()

    init(color: UIColor, font: UIFont, textColor: UIColor) {
        self.color = color
        self.font = font
        self.textColor = textColor

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        attrs = [.font: font, .paragraphStyle: paragraphStyle, .foregroundColor: textColor, .baselineOffset: NSNumber(value: -4)]
        super.init()
    }

    override func draw(context: CGContext, point: CGPoint) {
        // custom padding around text
        let labelWidth = labelText.size(withAttributes: attrs).width + 10
        // if you modify labelHeigh you will have to tweak baselineOffset in attrs
        let labelHeight = labelText.size(withAttributes: attrs).height + 4

        // place pill above the marker, centered along x
        var rectangle = CGRect(x: point.x, y: point.y, width: labelWidth, height: labelHeight)
        rectangle.origin.x -= rectangle.width / 2.0
        var spacing: CGFloat = 20
        if point.y < 300 { spacing = -40 }

        rectangle.origin.y -= rectangle.height + spacing

        // rounded rect
        let clipPath = UIBezierPath(roundedRect: rectangle, cornerRadius: 6.0).cgPath
        context.addPath(clipPath)
        context.setFillColor(UIColor.secondarySystemBackground.cgColor)
        context.setStrokeColor(UIColor.label.cgColor)
        context.closePath()
        context.drawPath(using: .fillStroke)

        // add the text
        labelText.draw(with: rectangle, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }

    private static let pillSeparator = "\r\r"

    override func refreshContent(entry: ChartDataEntry, highlight _: Highlight) {
        if let text = entry.data as? String {
            // Treatment entries use pillSeparator to separate the value label from the marker text.
            if let range = text.range(of: Self.pillSeparator) {
                labelText = String(text[range.upperBound...])
            } else {
                labelText = text
            }
        } else {
            labelText = String(entry.y)
        }
    }

    private func customString(_ value: Double) -> String {
        let formattedString = PillMarker.formatter.string(from: TimeInterval(value))!
        // using this to convert the left axis values formatting, ie 2 min
        return "\(formattedString)"
    }
}

// MARK: - Cone of Uncertainty

class ConeChartDataEntry: ChartDataEntry {
    var yMin: Double = 0.0
    var yMax: Double = 0.0

    required init() {
        super.init()
    }

    init(x: Double, yMin: Double, yMax: Double) {
        self.yMin = yMin
        self.yMax = yMax
        super.init(x: x, y: yMax)
    }

    override func copy(with _: NSZone? = nil) -> Any {
        let copy = ConeChartDataEntry(x: x, yMin: yMin, yMax: yMax)
        copy.data = data
        return copy
    }
}

class ConeOfUncertaintyRenderer: LineChartRenderer {
    let coneDataSetIndex: Int

    init(dataProvider: LineChartDataProvider?, animator: Animator?, viewPortHandler: ViewPortHandler?, coneDataSetIndex: Int) {
        self.coneDataSetIndex = coneDataSetIndex
        super.init(dataProvider: dataProvider!, animator: animator!, viewPortHandler: viewPortHandler!)
    }

    override func drawExtras(context: CGContext) {
        super.drawExtras(context: context)

        guard let dataProvider = dataProvider,
              dataProvider.lineData?.dataSets.count ?? 0 > coneDataSetIndex,
              let lineDataSet = dataProvider.lineData?.dataSets[coneDataSetIndex] as? LineChartDataSet,
              lineDataSet.entryCount > 1 else { return }

        let trans = dataProvider.getTransformer(forAxis: lineDataSet.axisDependency)
        let phaseY = animator.phaseY

        var upperPoints = [CGPoint]()
        var lowerPoints = [CGPoint]()

        for i in 0 ..< lineDataSet.entryCount {
            guard let entry = lineDataSet.entryForIndex(i) as? ConeChartDataEntry else { continue }
            upperPoints.append(trans.pixelForValues(x: entry.x, y: entry.yMax * phaseY))
            lowerPoints.append(trans.pixelForValues(x: entry.x, y: entry.yMin * phaseY))
        }

        guard upperPoints.count > 1 else { return }

        context.saveGState()

        let path = CGMutablePath()
        path.move(to: upperPoints[0])
        for i in 1 ..< upperPoints.count {
            path.addLine(to: upperPoints[i])
        }
        for i in stride(from: lowerPoints.count - 1, through: 0, by: -1) {
            path.addLine(to: lowerPoints[i])
        }
        path.closeSubpath()

        context.addPath(path)
        context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.4).cgColor)
        context.fillPath()

        context.restoreGState()
    }
}
