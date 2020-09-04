//
//  Chart.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Charts

final class OverrideFillFormatter: IFillFormatter {
    func getFillLinePosition(dataSet: ILineChartDataSet, dataProvider: LineChartDataProvider) -> CGFloat {
        return -40
    }
}

final class basalFillFormatter: IFillFormatter {
    func getFillLinePosition(dataSet: ILineChartDataSet, dataProvider: LineChartDataProvider) -> CGFloat {
        return 0
    }
}

final class ChartXValueFormatter: IAxisValueFormatter {
    

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        
        let dateFormatter = DateFormatter()
        //let timezoneOffset = TimeZone.current.secondsFromGMT()
        //let epochTimezoneOffset = value + Double(timezoneOffset)
        if dateTimeUtils.is24Hour() {
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
        }
        
        //let date = Date(timeIntervalSince1970: epochTimezoneOffset)
        let date = Date(timeIntervalSince1970: value)
        let formattedDate = dateFormatter.string(from: date)

        return formattedDate
    }
}

final class ChartYDataValueFormatter: IValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if entry.data != nil {
            return entry.data as? String ?? ""
        } else {
            return ""
        }
    }
}

final class ChartYOverrideValueFormatter: IValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if entry.data != nil {
            return entry.data as? String ?? ""
        } else {
            return ""
        }
    }
}

final class ChartYMMOLValueFormatter: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return bgUnits.toDisplayUnits(String(value))
    }
}



class ChartMarker: MarkerView {
    private var text = String()

    private let drawAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 15),
        //.foregroundColor: UIColor.white,
        //.backgroundColor: UIColor.darkGray
        .foregroundColor: UIColor.label,
        .backgroundColor: UIColor.secondarySystemBackground
    ]

    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        if entry.data != nil {
            text = entry.data as? String ?? ""
        } else {
            text = String(entry.y)
        }
    }

    override func draw(context: CGContext, point: CGPoint) {
        super.draw(context: context, point: point)

        let sizeForDrawing = text.size(withAttributes: drawAttributes)
        bounds.size = sizeForDrawing
        offset = CGPoint(x: -sizeForDrawing.width / 2, y: -sizeForDrawing.height - 4)

        let offset = offsetForDrawing(atPoint: point)
        let originPoint = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
        let rectForText = CGRect(origin: originPoint, size: sizeForDrawing)
        drawText(text: text, rect: rectForText, withAttributes: drawAttributes)
    }

    private func drawText(text: String, rect: CGRect, withAttributes attributes: [NSAttributedString.Key: Any]? = nil) {
        let size = bounds.size
        let centeredRect = CGRect(
            x: rect.origin.x + (rect.size.width - size.width) / 2,
            y: rect.origin.y + (rect.size.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: centeredRect, withAttributes: attributes)
    }
}

class PillMarker: MarkerImage {

    private (set) var color: UIColor
    private (set) var font: UIFont
    private (set) var textColor: UIColor
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
        let spacing: CGFloat = 20
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

    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        if entry.data != nil {
            //var multiplier = entry.data as! Double * 100.0
            //labelText = String(format: "%.0f%%", multiplier)
            labelText = entry.data as? String ?? ""
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
