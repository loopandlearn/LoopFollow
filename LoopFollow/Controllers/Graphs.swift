//
//  Graphs.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Charts
import UIKit

import Charts

class TriangleRenderer: LineChartRenderer {
    let smbDataSetIndex: Int
    
    init(dataProvider: LineChartDataProvider?, animator: Animator?, viewPortHandler: ViewPortHandler?, smbDataSetIndex: Int) {
        self.smbDataSetIndex = smbDataSetIndex
        super.init(dataProvider: dataProvider!, animator: animator!, viewPortHandler: viewPortHandler!)
    }
    
    override func drawExtras(context: CGContext) {
        super.drawExtras(context: context)
        
        guard let dataProvider = dataProvider else { return }
        
        if dataProvider.lineData?.dataSets.count ?? 0 > smbDataSetIndex, let lineDataSet = dataProvider.lineData?.dataSets[smbDataSetIndex] as? LineChartDataSet {
            let trans = dataProvider.getTransformer(forAxis: lineDataSet.axisDependency)
            let phaseY = animator.phaseY
            
            for j in 0 ..< lineDataSet.entryCount {
                guard let e = lineDataSet.entryForIndex(j) else { continue }
                
                let pt = trans.pixelForValues(x: e.x, y: e.y * phaseY)
                
                context.saveGState()
                context.beginPath()
                context.move(to: CGPoint(x: pt.x, y: pt.y + 9))
                context.addLine(to: CGPoint(x: pt.x - 5, y: pt.y - 1))
                context.addLine(to: CGPoint(x: pt.x + 5, y: pt.y - 1))
                context.closePath()
                
                context.setFillColor(lineDataSet.circleColors.first!.cgColor)
                context.fillPath()
                
                context.restoreGState()
            }
        }
    }
}

let ScaleXMax:Float = 150.0
extension MainViewController {
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if chartView == BGChartFull {
            BGChart.moveViewToX(entry.x)
        }
        if entry.data as? String == "hide"{
            BGChart.highlightValue(nil, callDelegate: false)
        }
        
    }
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        print("Chart Scaled: \(BGChart.scaleX), \(BGChart.scaleY)")
      
        // dont store huge values
        var scale: Float = Float(BGChart.scaleX)
        if(scale > ScaleXMax ) {
            scale = ScaleXMax
        }
        UserDefaultsRepository.chartScaleX.value = Float(scale)
    }

    func createGraph(){
        // Create the BG Graph Data
        let bgChartEntry = [ChartDataEntry]()
        let maxBG: Float = UserDefaultsRepository.minBGScale.value
        
        // Setup BG line details
        let lineBG = LineChartDataSet(entries:bgChartEntry, label: "")
        lineBG.circleRadius = CGFloat(globalVariables.dotBG)
        lineBG.circleColors = [NSUIColor.systemGreen]
        lineBG.drawCircleHoleEnabled = false
        lineBG.axisDependency = YAxis.AxisDependency.right
        lineBG.highlightEnabled = true
        lineBG.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            lineBG.lineWidth = 2
        } else {
            lineBG.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            lineBG.drawCirclesEnabled = true
        } else {
            lineBG.drawCirclesEnabled = false
        }
        lineBG.setDrawHighlightIndicators(false)
        lineBG.valueFont.withSize(50)
        
        // Setup Prediction line details
        let predictionChartEntry = [ChartDataEntry]()
        let linePrediction = LineChartDataSet(entries:predictionChartEntry, label: "")
        linePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        linePrediction.circleColors = [NSUIColor.systemPurple]
        linePrediction.colors = [NSUIColor.systemPurple]
        linePrediction.drawCircleHoleEnabled = false
        linePrediction.axisDependency = YAxis.AxisDependency.right
        linePrediction.highlightEnabled = true
        linePrediction.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            linePrediction.lineWidth = 2
        } else {
            linePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            linePrediction.drawCirclesEnabled = true
        } else {
            linePrediction.drawCirclesEnabled = false
        }
        linePrediction.setDrawHighlightIndicators(false)
        linePrediction.valueFont.withSize(50)
        
        // create Basal graph data
        let chartEntry = [ChartDataEntry]()
        let maxBasal = UserDefaultsRepository.minBasalScale.value
        let lineBasal = LineChartDataSet(entries:chartEntry, label: "")
        lineBasal.setDrawHighlightIndicators(false)
        lineBasal.setColor(NSUIColor.systemBlue, alpha: 0.5)
        lineBasal.lineWidth = 0
        lineBasal.drawFilledEnabled = true
        lineBasal.fillColor = NSUIColor.systemBlue
        lineBasal.fillAlpha = 0.5
        lineBasal.drawCirclesEnabled = false
        lineBasal.axisDependency = YAxis.AxisDependency.left
        lineBasal.highlightEnabled = true
        lineBasal.drawValuesEnabled = false
        lineBasal.fillFormatter = basalFillFormatter()
        
        // Boluses
        let chartEntryBolus = [ChartDataEntry]()
        let lineBolus = LineChartDataSet(entries:chartEntryBolus, label: "")
        lineBolus.circleRadius = CGFloat(globalVariables.dotBolus)
        lineBolus.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineBolus.drawCircleHoleEnabled = false
        lineBolus.setDrawHighlightIndicators(false)
        lineBolus.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineBolus.lineWidth = 0
        lineBolus.axisDependency = YAxis.AxisDependency.right
        lineBolus.valueFormatter = ChartYDataValueFormatter()
        lineBolus.valueTextColor = NSUIColor.label
        lineBolus.fillColor = NSUIColor.systemBlue
        lineBolus.fillAlpha = 0.6
        
            lineBolus.drawCirclesEnabled = true
            lineBolus.drawFilledEnabled = false
        
        if UserDefaultsRepository.showValues.value  {
            lineBolus.drawValuesEnabled = true
            lineBolus.highlightEnabled = false
        } else {
            lineBolus.drawValuesEnabled = false
            lineBolus.highlightEnabled = true
        }
        
        // Carbs
        let chartEntryCarbs = [ChartDataEntry]()
        let lineCarbs = LineChartDataSet(entries:chartEntryCarbs, label: "")
        lineCarbs.circleRadius = CGFloat(globalVariables.dotCarb)
        lineCarbs.circleColors = [NSUIColor.systemOrange.withAlphaComponent(0.75)]
        lineCarbs.drawCircleHoleEnabled = false
        lineCarbs.setDrawHighlightIndicators(false)
        lineCarbs.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineCarbs.lineWidth = 0
        lineCarbs.axisDependency = YAxis.AxisDependency.right
        lineCarbs.valueFormatter = ChartYDataValueFormatter()
        lineCarbs.valueTextColor = NSUIColor.label
        lineCarbs.fillColor = NSUIColor.systemOrange
        lineCarbs.fillAlpha = 0.6
       
            lineCarbs.drawCirclesEnabled = true
            lineCarbs.drawFilledEnabled = false
        
        if UserDefaultsRepository.showValues.value {
            lineCarbs.drawValuesEnabled = true
            lineCarbs.highlightEnabled = false
        } else {
            lineCarbs.drawValuesEnabled = false
            lineCarbs.highlightEnabled = true
        }
        
        // create Scheduled Basal graph data
        let chartBasalScheduledEntry = [ChartDataEntry]()
        let lineBasalScheduled = LineChartDataSet(entries:chartBasalScheduledEntry, label: "")
        lineBasalScheduled.setDrawHighlightIndicators(false)
        lineBasalScheduled.setColor(NSUIColor.systemBlue, alpha: 0.8)
        lineBasalScheduled.lineWidth = 2
        lineBasalScheduled.drawFilledEnabled = false
        lineBasalScheduled.drawCirclesEnabled = false
        lineBasalScheduled.axisDependency = YAxis.AxisDependency.left
        lineBasalScheduled.highlightEnabled = false
        lineBasalScheduled.drawValuesEnabled = false
        lineBasalScheduled.lineDashLengths = [10.0, 5.0]
        
        // create Override graph data
        let chartOverrideEntry = [ChartDataEntry]()
        let lineOverride = LineChartDataSet(entries:chartOverrideEntry, label: "")
        lineOverride.setDrawHighlightIndicators(false)
        lineOverride.lineWidth = 0
        lineOverride.drawFilledEnabled = true
        lineOverride.fillFormatter = OverrideFillFormatter()
        lineOverride.fillColor = NSUIColor.systemGreen
        lineOverride.fillAlpha = 0.6
        lineOverride.drawCirclesEnabled = false
        lineOverride.axisDependency = YAxis.AxisDependency.right
        lineOverride.highlightEnabled = true
        lineOverride.drawValuesEnabled = false
        
        // BG Check
        let chartEntryBGCheck = [ChartDataEntry]()
        let lineBGCheck = LineChartDataSet(entries:chartEntryBGCheck, label: "")
        lineBGCheck.circleRadius = CGFloat(globalVariables.dotOther)
        lineBGCheck.circleColors = [NSUIColor.systemRed.withAlphaComponent(0.75)]
        lineBGCheck.drawCircleHoleEnabled = false
        lineBGCheck.setDrawHighlightIndicators(false)
        lineBGCheck.setColor(NSUIColor.systemRed, alpha: 1.0)
        lineBGCheck.drawCirclesEnabled = true
        lineBGCheck.lineWidth = 0
        lineBGCheck.highlightEnabled = true
        lineBGCheck.axisDependency = YAxis.AxisDependency.right
        lineBGCheck.valueFormatter = ChartYDataValueFormatter()
        lineBGCheck.drawValuesEnabled = false
        
        // Suspend Pump
        let chartEntrySuspend = [ChartDataEntry]()
        let lineSuspend = LineChartDataSet(entries:chartEntrySuspend, label: "")
        lineSuspend.circleRadius = CGFloat(globalVariables.dotOther)
        lineSuspend.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineSuspend.drawCircleHoleEnabled = false
        lineSuspend.setDrawHighlightIndicators(false)
        lineSuspend.setColor(NSUIColor.systemGray2, alpha: 1.0)
        lineSuspend.drawCirclesEnabled = true
        lineSuspend.lineWidth = 0
        lineSuspend.highlightEnabled = true
        lineSuspend.axisDependency = YAxis.AxisDependency.right
        lineSuspend.valueFormatter = ChartYDataValueFormatter()
        lineSuspend.drawValuesEnabled = false
        
        // Resume Pump
        let chartEntryResume = [ChartDataEntry]()
        let lineResume = LineChartDataSet(entries:chartEntryResume, label: "")
        lineResume.circleRadius = CGFloat(globalVariables.dotOther)
        lineResume.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineResume.drawCircleHoleEnabled = false
        lineResume.setDrawHighlightIndicators(false)
        lineResume.setColor(NSUIColor.systemGray4, alpha: 1.0)
        lineResume.drawCirclesEnabled = true
        lineResume.lineWidth = 0
        lineResume.highlightEnabled = true
        lineResume.axisDependency = YAxis.AxisDependency.right
        lineResume.valueFormatter = ChartYDataValueFormatter()
        lineResume.drawValuesEnabled = false
        
        // Sensor Start
        let chartEntrySensor = [ChartDataEntry]()
        let lineSensor = LineChartDataSet(entries:chartEntrySensor, label: "")
        lineSensor.circleRadius = CGFloat(globalVariables.dotOther)
        lineSensor.circleColors = [NSUIColor.systemIndigo.withAlphaComponent(0.75)]
        lineSensor.drawCircleHoleEnabled = false
        lineSensor.setDrawHighlightIndicators(false)
        lineSensor.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineSensor.drawCirclesEnabled = true
        lineSensor.lineWidth = 0
        lineSensor.highlightEnabled = true
        lineSensor.axisDependency = YAxis.AxisDependency.right
        lineSensor.valueFormatter = ChartYDataValueFormatter()
        lineSensor.drawValuesEnabled = false
        
        // Notes
        let chartEntryNote = [ChartDataEntry]()
        let lineNote = LineChartDataSet(entries:chartEntryNote, label: "")
        lineNote.circleRadius = CGFloat(globalVariables.dotOther)
        lineNote.circleColors = [NSUIColor.systemGray.withAlphaComponent(0.75)]
        lineNote.drawCircleHoleEnabled = false
        lineNote.setDrawHighlightIndicators(false)
        lineNote.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineNote.drawCirclesEnabled = true
        lineNote.lineWidth = 0
        lineNote.highlightEnabled = true
        lineNote.axisDependency = YAxis.AxisDependency.right
        lineNote.valueFormatter = ChartYDataValueFormatter()
        lineNote.drawValuesEnabled = false

        // Setup COB Prediction line details
        let COBpredictionChartEntry = [ChartDataEntry]()
        let COBlinePrediction = LineChartDataSet(entries:COBpredictionChartEntry, label: "")
        COBlinePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        COBlinePrediction.circleColors = [NSUIColor.systemPurple]
        COBlinePrediction.colors = [NSUIColor.systemPurple]
        COBlinePrediction.drawCircleHoleEnabled = false
        COBlinePrediction.axisDependency = YAxis.AxisDependency.right
        COBlinePrediction.highlightEnabled = true
        COBlinePrediction.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            COBlinePrediction.lineWidth = 2
        } else {
            COBlinePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            COBlinePrediction.drawCirclesEnabled = true
        } else {
            COBlinePrediction.drawCirclesEnabled = false
        }
        COBlinePrediction.setDrawHighlightIndicators(false)
        COBlinePrediction.valueFont.withSize(50)
        
        // Setup IOB Prediction line details
        let IOBpredictionChartEntry = [ChartDataEntry]()
        let IOBlinePrediction = LineChartDataSet(entries:IOBpredictionChartEntry, label: "")
        IOBlinePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        IOBlinePrediction.circleColors = [NSUIColor.systemPurple]
        IOBlinePrediction.colors = [NSUIColor.systemPurple]
        IOBlinePrediction.drawCircleHoleEnabled = false
        IOBlinePrediction.axisDependency = YAxis.AxisDependency.right
        IOBlinePrediction.highlightEnabled = true
        IOBlinePrediction.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            IOBlinePrediction.lineWidth = 2
        } else {
            IOBlinePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            IOBlinePrediction.drawCirclesEnabled = true
        } else {
            IOBlinePrediction.drawCirclesEnabled = false
        }
        IOBlinePrediction.setDrawHighlightIndicators(false)
        IOBlinePrediction.valueFont.withSize(50)
        
        // Setup UAM Prediction line details
        let UAMpredictionChartEntry = [ChartDataEntry]()
        let UAMlinePrediction = LineChartDataSet(entries:UAMpredictionChartEntry, label: "")
        UAMlinePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        UAMlinePrediction.circleColors = [NSUIColor.systemPurple]
        UAMlinePrediction.colors = [NSUIColor.systemPurple]
        UAMlinePrediction.drawCircleHoleEnabled = false
        UAMlinePrediction.axisDependency = YAxis.AxisDependency.right
        UAMlinePrediction.highlightEnabled = true
        UAMlinePrediction.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            UAMlinePrediction.lineWidth = 2
        } else {
            UAMlinePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            UAMlinePrediction.drawCirclesEnabled = true
        } else {
            UAMlinePrediction.drawCirclesEnabled = false
        }
        linePrediction.setDrawHighlightIndicators(false)
        linePrediction.valueFont.withSize(50)
        
        // Setup ZT Prediction line details
        let ZTpredictionChartEntry = [ChartDataEntry]()
        let ZTlinePrediction = LineChartDataSet(entries:ZTpredictionChartEntry, label: "")
        ZTlinePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        ZTlinePrediction.circleColors = [NSUIColor.systemPurple]
        ZTlinePrediction.colors = [NSUIColor.systemPurple]
        ZTlinePrediction.drawCircleHoleEnabled = false
        ZTlinePrediction.axisDependency = YAxis.AxisDependency.right
        ZTlinePrediction.highlightEnabled = true
        ZTlinePrediction.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            ZTlinePrediction.lineWidth = 2
        } else {
            ZTlinePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            ZTlinePrediction.drawCirclesEnabled = true
        } else {
            ZTlinePrediction.drawCirclesEnabled = false
        }
        ZTlinePrediction.setDrawHighlightIndicators(false)
        ZTlinePrediction.valueFont.withSize(50)

        // SMB
        let chartEntrySmb = [ChartDataEntry]()
        let lineSmb = LineChartDataSet(entries: chartEntrySmb, label: "")
        lineSmb.circleRadius = CGFloat(globalVariables.dotBolus)
        lineSmb.circleColors = [NSUIColor.systemBlue.withAlphaComponent(1.0)]
        lineSmb.drawCircleHoleEnabled = false
        lineSmb.setDrawHighlightIndicators(false)
        lineSmb.setColor(NSUIColor.red, alpha: 1.0)
        lineSmb.lineWidth = 0
        lineSmb.axisDependency = YAxis.AxisDependency.right
        lineSmb.valueFormatter = ChartYDataValueFormatter()
        lineSmb.valueTextColor = NSUIColor.label
        
        lineSmb.drawCirclesEnabled = false
        lineSmb.drawFilledEnabled = false
        
        if UserDefaultsRepository.showValues.value {
            lineSmb.drawValuesEnabled = true
            lineSmb.highlightEnabled = false
        } else {
            lineSmb.drawValuesEnabled = false
            lineSmb.highlightEnabled = true
        }
        
        // Setup the chart data of all lines
        let data = LineChartData()
        
        data.append(lineBG) // Dataset 0
        data.append(linePrediction) // Dataset 1
        data.append(lineBasal) // Dataset 2
        data.append(lineBolus) // Dataset 3
        data.append(lineCarbs) // Dataset 4
        data.append(lineBasalScheduled) // Dataset 5
        data.append(lineOverride) // Dataset 6
        data.append(lineBGCheck) // Dataset 7
        data.append(lineSuspend) // Dataset 8
        data.append(lineResume) // Dataset 9
        data.append(lineSensor) // Dataset 10
        data.append(lineNote) // Dataset 11
        data.append(ZTlinePrediction) // Dataset 12
        data.append(IOBlinePrediction) // Dataset 13
        data.append(COBlinePrediction) // Dataset 14
        data.append(UAMlinePrediction) // Dataset 15
        data.append(lineSmb) // Dataset 16

        data.setValueFont(UIFont.systemFont(ofSize: 12))
        
        // Add marker popups for bolus and carbs
        let marker = PillMarker(color: .secondarySystemBackground, font: UIFont.boldSystemFont(ofSize: 14), textColor: .label)
        BGChart.marker = marker
        
        // Clear limit lines so they don't add multiples when changing the settings
        BGChart.rightAxis.removeAllLimitLines()
        
        //Add lower red line based on low alert value
        let ll = ChartLimitLine()
        ll.limit = Double(UserDefaultsRepository.lowLine.value)
        ll.lineColor = NSUIColor.systemRed.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ll)
        
        //Add upper yellow line based on low alert value
        let ul = ChartLimitLine()
        ul.limit = Double(UserDefaultsRepository.highLine.value)
        ul.lineColor = NSUIColor.systemYellow.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ul)
        
        // Add vertical lines as configured
        createVerticalLines()
        startGraphNowTimer()
        
        // Setup the main graph overall details
        BGChart.xAxis.valueFormatter = ChartXValueFormatter()
        BGChart.xAxis.granularity = 1800
        BGChart.xAxis.labelTextColor = NSUIColor.label
        BGChart.xAxis.labelPosition = XAxis.LabelPosition.bottom
        BGChart.xAxis.drawGridLinesEnabled = false
        
        BGChart.leftAxis.enabled = true
        BGChart.leftAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.leftAxis.axisMaximum = maxBasal
        BGChart.leftAxis.axisMinimum = 0
        BGChart.leftAxis.drawGridLinesEnabled = false
        BGChart.leftAxis.granularityEnabled = true
        BGChart.leftAxis.granularity = 0.5
        
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 0.0
        BGChart.rightAxis.axisMaximum = Double(maxBG)
        BGChart.rightAxis.gridLineDashLengths = [5.0, 5.0]
        BGChart.rightAxis.drawGridLinesEnabled = false
        BGChart.rightAxis.valueFormatter = ChartYMMOLValueFormatter()
        BGChart.rightAxis.granularityEnabled = true
        BGChart.rightAxis.granularity = 50
        
        BGChart.maxHighlightDistance = 15.0
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.drawGridBackgroundEnabled = true
        BGChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        
        BGChart.highlightValue(nil, callDelegate: false)
        
        BGChart.data = data
        BGChart.setExtraOffsets(left: 5, top: 10, right: 5, bottom: 10)
    }
    
    func createVerticalLines() {
        BGChart.xAxis.removeAllLimitLines()
        BGChartFull.xAxis.removeAllLimitLines()
        createNowAndDIALines()
        createMidnightLines()
    }
    
    func createNowAndDIALines() {
        let ul = ChartLimitLine()
        ul.limit = Double(dateTimeUtils.getNowTimeIntervalUTC())
        ul.lineColor = NSUIColor.systemGray.withAlphaComponent(0.5)
        ul.lineWidth = 1
        BGChart.xAxis.addLimitLine(ul)
        
        if UserDefaultsRepository.show30MinLine.value {
            let ul2 = ChartLimitLine()
            ul2.limit = Double(dateTimeUtils.getNowTimeIntervalUTC().advanced(by: -30 * 60))
            ul2.lineColor = NSUIColor.systemBlue.withAlphaComponent(0.5)
            ul2.lineWidth = 1
            BGChart.xAxis.addLimitLine(ul2)
        }
        
        if UserDefaultsRepository.showDIALines.value {
            for i in 1..<7 {
                let ul = ChartLimitLine()
                ul.limit = Double(dateTimeUtils.getNowTimeIntervalUTC() - Double(i * 60 * 60))
                ul.lineColor = NSUIColor.systemGray.withAlphaComponent(0.3)
                let dash = 10.0 - Double(i)
                let space = 5.0 + Double(i)
                ul.lineDashLengths = [CGFloat(dash), CGFloat(space)]
                ul.lineWidth = 1
                BGChart.xAxis.addLimitLine(ul)
            }
        }

        if UserDefaultsRepository.show90MinLine.value {
            let ul3 = ChartLimitLine()
            ul3.limit = Double(dateTimeUtils.getNowTimeIntervalUTC().advanced(by: -90 * 60))
            ul3.lineColor = NSUIColor.systemOrange.withAlphaComponent(0.5)
            ul3.lineWidth = 1
            BGChart.xAxis.addLimitLine(ul3)
        }
    }
    
    func createMidnightLines() {
        // Draw a line at midnight: useful when showing multiple days of data
        if UserDefaultsRepository.showMidnightLines.value {
            var midnightTimeInterval = dateTimeUtils.getTimeIntervalMidnightToday()
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            let graphStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            while midnightTimeInterval > graphStart {
                // Large chart
                let ul = ChartLimitLine()
                ul.limit = Double(midnightTimeInterval)
                ul.lineColor = NSUIColor.systemTeal.withAlphaComponent(0.5)
                ul.lineDashLengths = [CGFloat(2), CGFloat(5)]
                ul.lineWidth = 1
                BGChart.xAxis.addLimitLine(ul)

                // Small chart
                let sl = ChartLimitLine()
                sl.limit = Double(midnightTimeInterval)
                sl.lineColor = NSUIColor.systemTeal
                sl.lineDashLengths = [CGFloat(2), CGFloat(2)]
                sl.lineWidth = 1
                BGChartFull.xAxis.addLimitLine(sl)
                
                midnightTimeInterval = midnightTimeInterval.advanced(by: -24*60*60)
            }
        }
    }
    
    func updateBGGraphSettings() {
        let dataIndex = 0
        let dataIndexPrediction = 1
        let lineBG = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let linePrediction = BGChart.lineData!.dataSets[dataIndexPrediction] as! LineChartDataSet
        if UserDefaultsRepository.showLines.value {
            lineBG.lineWidth = 2
            linePrediction.lineWidth = 2
        } else {
            lineBG.lineWidth = 0
            linePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            lineBG.drawCirclesEnabled = true
            linePrediction.drawCirclesEnabled = true
        } else {
            lineBG.drawCirclesEnabled = false
            linePrediction.drawCirclesEnabled = false
        }
        
        BGChart.rightAxis.axisMinimum = 0
        
        // Clear limit lines so they don't add multiples when changing the settings
        BGChart.rightAxis.removeAllLimitLines()
        
        //Add lower red line based on low alert value
        let ll = ChartLimitLine()
        ll.limit = Double(UserDefaultsRepository.lowLine.value)
        ll.lineColor = NSUIColor.systemRed.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ll)
        
        //Add upper yellow line based on low alert value
        let ul = ChartLimitLine()
        ul.limit = Double(UserDefaultsRepository.highLine.value)
        ul.lineColor = NSUIColor.systemYellow.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ul)
        
        // Re-create vertical markers in case their settings changed
        createVerticalLines()
    
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        
    }
    
    func updateBGGraph() {
        if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "##### Start BG Graph #####") }
        let dataIndex = 0
        let entries = bgData
        guard !entries.isEmpty else {
            return
        }
        let mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.removeAll(keepingCapacity: false)
        smallChart.removeAll(keepingCapacity: false)
        let maxBGOffset: Float = 50
        
        var colors = [NSUIColor]()

        topBG = UserDefaultsRepository.minBGScale.value
        for i in 0..<entries.count{
            if Float(entries[i].sgv) > topBG - maxBGOffset {
                topBG = Float(entries[i].sgv) + maxBGOffset
            }
            let value = ChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].sgv), data: formatPillText(line1: bgUnits.toDisplayUnits(String(entries[i].sgv)), time: entries[i].date))
            if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "BG: " + value.description) }
            mainChart.append(value)
            smallChart.append(value)
            
            if Double(entries[i].sgv) >= Double(UserDefaultsRepository.highLine.value) {
                colors.append(NSUIColor.systemYellow)
            } else if Double(entries[i].sgv) <= Double(UserDefaultsRepository.lowLine.value) {
               colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "Total Graph BGs: " + mainChart.entries.count.description) }        
        
        // Set Colors
        let lineBG = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet

        let lineBGSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineBG.colors.removeAll()
        lineBG.circleColors.removeAll()
        lineBGSmall.colors.removeAll()
        lineBGSmall.circleColors.removeAll()

        if colors.count > 0 {
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "Total Colors: " + mainChart.colors.count.description) }
        
        BGChart.rightAxis.axisMaximum = Double(calculateMaxBgGraphValue())
        BGChart.setVisibleXRangeMinimum(600)
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        BGChartFull.rightAxis.axisMaximum = Double(calculateMaxBgGraphValue())
        BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChartFull.data?.notifyDataChanged()
        BGChartFull.notifyDataSetChanged()
        
        if firstGraphLoad {
            var scaleX = CGFloat(UserDefaultsRepository.chartScaleX.value)
            print("Scale: \(scaleX)")
            if( scaleX > CGFloat(ScaleXMax) ) {
                scaleX = CGFloat(ScaleXMax)
                UserDefaultsRepository.chartScaleX.value = ScaleXMax
            }
            BGChart.zoom(scaleX: scaleX, scaleY: 1, x: 1, y: 1)
            firstGraphLoad = false
        }
        
        // Move to current reading everytime new readings load
        // Check if auto-scrolling should be performed
        if autoScrollPauseUntil == nil || Date() > autoScrollPauseUntil! {
            BGChart.moveViewToAnimated(xValue: dateTimeUtils.getNowTimeIntervalUTC() - (BGChart.visibleXRange * 0.7), yValue: 0.0, axis: .right, duration: 1, easingOption: .easeInBack)
        }
    }
    
    func updatePredictionGraph(color: UIColor? = nil) {
        let dataIndex = 1
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        
        var colors = [NSUIColor]()
        let maxBGOffset: Float = 20

        topPredictionBG = UserDefaultsRepository.minBGScale.value
        for i in 0..<predictionData.count {
            var predictionVal = Double(predictionData[i].sgv)
            if Float(predictionVal) > topPredictionBG - maxBGOffset {
                topPredictionBG = Float(predictionVal) + maxBGOffset
            }
            
            if i == 0 {
                if UserDefaultsRepository.showDots.value {
                    colors.append((color ?? NSUIColor.systemPurple).withAlphaComponent(0.0))
                } else {
                    colors.append((color ?? NSUIColor.systemPurple).withAlphaComponent(1.0))
                }
            } else if predictionVal > 400 {
                colors.append(color ?? NSUIColor.systemYellow)
            } else if predictionVal < 0 {
                colors.append(color ?? NSUIColor.systemRed)
            } else {
                colors.append(color ?? NSUIColor.systemPurple)
            }
            
            let value = ChartDataEntry(x: predictionData[i].date, y: predictionVal, data: formatPillText(line1: bgUnits.toDisplayUnits(String(predictionData[i].sgv)), time: predictionData[i].date))
            mainChart.addEntry(value)
            smallChart.addEntry(value)
        }
        
        smallChart.circleColors.removeAll()
        smallChart.colors.removeAll()
        mainChart.colors.removeAll()
        mainChart.circleColors.removeAll()
        if colors.count > 0 {
            for i in 0..<colors.count {
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        BGChart.rightAxis.axisMaximum = Double(calculateMaxBgGraphValue())
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChartFull.data?.notifyDataChanged()
        BGChartFull.notifyDataSetChanged()
    }
    
    func updateBasalGraph() {
        var dataIndex = 2
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        var maxBasalSmall: Double = 0.0
        for i in 0..<basalData.count{
            let value = ChartDataEntry(x: Double(basalData[i].date), y: Double(basalData[i].basalRate), data: formatPillText(line1: String(basalData[i].basalRate), time: basalData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
            if basalData[i].basalRate  > maxBasal {
                maxBasal = basalData[i].basalRate
            }
            if basalData[i].basalRate > maxBasalSmall {
                maxBasalSmall = basalData[i].basalRate
            }
        }
        
        BGChart.leftAxis.axisMaximum = maxBasal
        BGChartFull.leftAxis.axisMaximum = maxBasalSmall
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBasalScheduledGraph() {
        var dataIndex = 5
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        for i in 0..<basalScheduleData.count{
            let value = ChartDataEntry(x: Double(basalScheduleData[i].date), y: Double(basalScheduleData[i].basalRate))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBolusGraph() {
        var dataIndex = 3
        var yTop: Double = 370
        var yBottom: Double = 345
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        
        var colors = [NSUIColor]()
        for i in 0..<bolusData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 0
            
            // Check overlapping carbs to shift left if needed
            let bolusShift = findNextBolusTime(timeWithin: 240, needle: bolusData[i].date, haystack: bolusData, startingIndex: i)
            var dateTimeStamp = bolusData[i].date
            
            colors.append(NSUIColor.systemBlue.withAlphaComponent(1.0))
            
            if bolusShift {
                // Move it half the distance between BG readings
                dateTimeStamp = dateTimeStamp - 150
            }
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
  
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(bolusData[i].sgv), data: formatter.string(from: NSNumber(value: bolusData[i].value)))
            mainChart.addEntry(dot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                smallChart.addEntry(dot)
            }
        }
        
        // Set Colors
        let lineBolus = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let lineBolusSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineBolus.colors.removeAll()
        lineBolus.circleColors.removeAll()
        lineBolusSmall.colors.removeAll()
        lineBolusSmall.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSmbGraph() {
        var dataIndex = 16
        var yTop: Double = 370
        var yBottom: Double = 345
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        let lightBlue = NSUIColor(red: 135/255, green: 206/255, blue: 235/255, alpha: 1.0) // Light Sky Blue
        
        var colors = [NSUIColor]()
        for i in 0..<smbData.count {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 0
            
            let bolusShift = findNextBolusTime(timeWithin: 240, needle: smbData[i].date, haystack: smbData, startingIndex: i)
            var dateTimeStamp = smbData[i].date
            
            let nowTime = dateTimeUtils.getNowTimeIntervalUTC()
            let diffTimeHours = (nowTime - dateTimeStamp) / 60 / 60
            if diffTimeHours <= 1 {
                colors.append(lightBlue.withAlphaComponent(1.0))
            } else if diffTimeHours > 6 {
                colors.append(lightBlue.withAlphaComponent(0.25))
            } else {
                let thisAlpha = 1.0 - (0.15 * diffTimeHours)
                colors.append(lightBlue.withAlphaComponent(CGFloat(thisAlpha)))
            }
            
            if bolusShift {
                dateTimeStamp = dateTimeStamp - 150
            }
            
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(smbData[i].sgv), data: formatter.string(from: NSNumber(value: smbData[i].value)))
            mainChart.addEntry(dot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                smallChart.addEntry(dot)
            }
        }
        
        let smbRenderer = TriangleRenderer(dataProvider: BGChart, animator: Animator(), viewPortHandler: BGChart.viewPortHandler, smbDataSetIndex: dataIndex)
        BGChart.renderer = smbRenderer
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateCarbGraph() {
        var dataIndex = 4
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        
        var colors = [NSUIColor]()
        for i in 0..<carbData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 1

            
            var valueString: String = formatter.string(from: NSNumber(value: carbData[i].value))!
            
            var hours = 3
            if carbData[i].absorptionTime > 0 && UserDefaultsRepository.showAbsorption.value {
                hours = carbData[i].absorptionTime / 60
                valueString += " " + String(hours) + "h"
            }
            
            // Check overlapping carbs to shift left if needed
            let carbShift = findNextCarbTime(timeWithin: 250, needle: carbData[i].date, haystack: carbData, startingIndex: i)
            var dateTimeStamp = carbData[i].date
            
            colors.append(NSUIColor.systemOrange.withAlphaComponent(1.0))
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            if carbShift {
                dateTimeStamp = dateTimeStamp - 250
            }
            
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(carbData[i].sgv), data: valueString)
            BGChart.data?.dataSets[dataIndex].addEntry(dot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(dot)
            }
            
            

        }
        
        // Set Colors
        let lineCarbs = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let lineCarbsSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineCarbs.colors.removeAll()
        lineCarbs.circleColors.removeAll()
        lineCarbsSmall.colors.removeAll()
        lineCarbsSmall.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBGCheckGraph() {
        var dataIndex = 7
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        
        for i in 0..<bgCheckData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 1
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if bgCheckData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(bgCheckData[i].date), y: Double(bgCheckData[i].sgv), data: formatPillText(line1: bgUnits.toDisplayUnits(String(bgCheckData[i].sgv)), time: bgCheckData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSuspendGraph() {
        var dataIndex = 8
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = suspendGraphData
        for i in 0..<thisData.count{
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: "Suspend Pump", time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateResumeGraph() {
        var dataIndex = 9
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = resumeGraphData
        for i in 0..<thisData.count{
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: "Resume Pump", time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSensorStart() {
        var dataIndex = 10
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = sensorStartGraphData
        for i in 0..<thisData.count{
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: "Start Sensor", time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateNotes() {
        var dataIndex = 11
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = noteGraphData
        for i in 0..<thisData.count{
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: thisData[i].note, time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
 
    func createSmallBGGraph(){
        let entries = bgData
       var bgChartEntry = [ChartDataEntry]()
       var colors = [NSUIColor]()
        var maxBG: Float = UserDefaultsRepository.minBGScale.value
        
        let lineBG = LineChartDataSet(entries:bgChartEntry, label: "")
        
        lineBG.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        lineBG.highlightEnabled = true
        lineBG.drawHorizontalHighlightIndicatorEnabled = false
        lineBG.drawVerticalHighlightIndicatorEnabled = false
        lineBG.highlightColor = NSUIColor.label
        lineBG.drawValuesEnabled = false
        lineBG.lineWidth = 1.5
        lineBG.axisDependency = YAxis.AxisDependency.right
        
        // Setup Prediction line details
        var predictionChartEntry = [ChartDataEntry]()
        let linePrediction = LineChartDataSet(entries:predictionChartEntry, label: "")
        linePrediction.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        linePrediction.setColor(NSUIColor.systemPurple)
        linePrediction.highlightEnabled = true
        linePrediction.drawHorizontalHighlightIndicatorEnabled = false
        linePrediction.drawVerticalHighlightIndicatorEnabled = false
        linePrediction.highlightColor = NSUIColor.label
        linePrediction.drawValuesEnabled = false
        linePrediction.lineWidth = 1.5
        linePrediction.axisDependency = YAxis.AxisDependency.right
        
        // create Basal graph data
        var chartEntry = [ChartDataEntry]()
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        let lineBasal = LineChartDataSet(entries:chartEntry, label: "")
        lineBasal.setDrawHighlightIndicators(false)
        lineBasal.setColor(NSUIColor.systemBlue, alpha: 0.5)
        lineBasal.lineWidth = 0
        lineBasal.drawFilledEnabled = true
        lineBasal.fillColor = NSUIColor.systemBlue
        lineBasal.fillAlpha = 0.35
        lineBasal.drawCirclesEnabled = false
        lineBasal.axisDependency = YAxis.AxisDependency.left
        lineBasal.highlightEnabled = false
        lineBasal.drawValuesEnabled = false
        lineBasal.fillFormatter = basalFillFormatter()
        
        // Boluses
        var chartEntryBolus = [ChartDataEntry]()
        let lineBolus = LineChartDataSet(entries:chartEntryBolus, label: "")
        lineBolus.circleRadius = 2
        lineBolus.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineBolus.drawCircleHoleEnabled = false
        lineBolus.setDrawHighlightIndicators(false)
        lineBolus.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineBolus.lineWidth = 0
        lineBolus.axisDependency = YAxis.AxisDependency.right
        lineBolus.valueFormatter = ChartYDataValueFormatter()
        lineBolus.valueTextColor = NSUIColor.label
        lineBolus.fillColor = NSUIColor.systemBlue
        lineBolus.fillAlpha = 0.6
        lineBolus.drawCirclesEnabled = true
        lineBolus.drawFilledEnabled = false
        lineBolus.drawValuesEnabled = false
        lineBolus.highlightEnabled = false
        

        
        // Carbs
        var chartEntryCarbs = [ChartDataEntry]()
        let lineCarbs = LineChartDataSet(entries:chartEntryCarbs, label: "")
        lineCarbs.circleRadius = 2
        lineCarbs.circleColors = [NSUIColor.systemOrange.withAlphaComponent(0.75)]
        lineCarbs.drawCircleHoleEnabled = false
        lineCarbs.setDrawHighlightIndicators(false)
        lineCarbs.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineCarbs.lineWidth = 0
        lineCarbs.axisDependency = YAxis.AxisDependency.right
        lineCarbs.valueFormatter = ChartYDataValueFormatter()
        lineCarbs.valueTextColor = NSUIColor.label
        lineCarbs.fillColor = NSUIColor.systemOrange
        lineCarbs.fillAlpha = 0.6
        lineCarbs.drawCirclesEnabled = true
        lineCarbs.drawFilledEnabled = false
        lineCarbs.drawValuesEnabled = false
        lineCarbs.highlightEnabled = false
        
        
        
        // create Scheduled Basal graph data
        var chartBasalScheduledEntry = [ChartDataEntry]()
        let lineBasalScheduled = LineChartDataSet(entries:chartBasalScheduledEntry, label: "")
        lineBasalScheduled.setDrawHighlightIndicators(false)
        lineBasalScheduled.setColor(NSUIColor.systemBlue, alpha: 0.8)
        lineBasalScheduled.lineWidth = 0.5
        lineBasalScheduled.drawFilledEnabled = false
        lineBasalScheduled.drawCirclesEnabled = false
        lineBasalScheduled.axisDependency = YAxis.AxisDependency.left
        lineBasalScheduled.highlightEnabled = false
        lineBasalScheduled.drawValuesEnabled = false
        lineBasalScheduled.lineDashLengths = [2, 1]
        
        // create Override graph data
        var chartOverrideEntry = [ChartDataEntry]()
        let lineOverride = LineChartDataSet(entries:chartOverrideEntry, label: "")
        lineOverride.setDrawHighlightIndicators(false)
        lineOverride.lineWidth = 0
        lineOverride.drawFilledEnabled = true
        lineOverride.fillFormatter = OverrideFillFormatter()
        lineOverride.fillColor = NSUIColor.systemGreen
        lineOverride.fillAlpha = 0.6
        lineOverride.drawCirclesEnabled = false
        lineOverride.axisDependency = YAxis.AxisDependency.right
        lineOverride.highlightEnabled = true
        lineOverride.drawValuesEnabled = false
        
        // BG Check
        var chartEntryBGCheck = [ChartDataEntry]()
        let lineBGCheck = LineChartDataSet(entries:chartEntryBGCheck, label: "")
        lineBGCheck.circleRadius = 2
        lineBGCheck.circleColors = [NSUIColor.systemRed.withAlphaComponent(0.75)]
        lineBGCheck.drawCircleHoleEnabled = false
        lineBGCheck.setDrawHighlightIndicators(false)
        lineBGCheck.setColor(NSUIColor.systemRed, alpha: 1.0)
        lineBGCheck.drawCirclesEnabled = true
        lineBGCheck.lineWidth = 0
        lineBGCheck.highlightEnabled = false
        lineBGCheck.axisDependency = YAxis.AxisDependency.right
        lineBGCheck.valueFormatter = ChartYDataValueFormatter()
        lineBGCheck.drawValuesEnabled = false
        
        // Suspend Pump
        var chartEntrySuspend = [ChartDataEntry]()
        let lineSuspend = LineChartDataSet(entries:chartEntrySuspend, label: "")
        lineSuspend.circleRadius = 2
        lineSuspend.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineSuspend.drawCircleHoleEnabled = false
        lineSuspend.setDrawHighlightIndicators(false)
        lineSuspend.setColor(NSUIColor.systemGray2, alpha: 1.0)
        lineSuspend.drawCirclesEnabled = true
        lineSuspend.lineWidth = 0
        lineSuspend.highlightEnabled = false
        lineSuspend.axisDependency = YAxis.AxisDependency.right
        lineSuspend.valueFormatter = ChartYDataValueFormatter()
        lineSuspend.drawValuesEnabled = false
        
        // Resume Pump
        var chartEntryResume = [ChartDataEntry]()
        let lineResume = LineChartDataSet(entries:chartEntryResume, label: "")
        lineResume.circleRadius = 2
        lineResume.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineResume.drawCircleHoleEnabled = false
        lineResume.setDrawHighlightIndicators(false)
        lineResume.setColor(NSUIColor.systemGray4, alpha: 1.0)
        lineResume.drawCirclesEnabled = true
        lineResume.lineWidth = 0
        lineResume.highlightEnabled = false
        lineResume.axisDependency = YAxis.AxisDependency.right
        lineResume.valueFormatter = ChartYDataValueFormatter()
        lineResume.drawValuesEnabled = false
        
        // Sensor Start
        var chartEntrySensor = [ChartDataEntry]()
        let lineSensor = LineChartDataSet(entries:chartEntrySensor, label: "")
        lineSensor.circleRadius = 2
        lineSensor.circleColors = [NSUIColor.systemIndigo.withAlphaComponent(0.75)]
        lineSensor.drawCircleHoleEnabled = false
        lineSensor.setDrawHighlightIndicators(false)
        lineSensor.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineSensor.drawCirclesEnabled = true
        lineSensor.lineWidth = 0
        lineSensor.highlightEnabled = false
        lineSensor.axisDependency = YAxis.AxisDependency.right
        lineSensor.valueFormatter = ChartYDataValueFormatter()
        lineSensor.drawValuesEnabled = false
        
        // Notes
        var chartEntryNote = [ChartDataEntry]()
        let lineNote = LineChartDataSet(entries:chartEntryNote, label: "")
        lineNote.circleRadius = 2
        lineNote.circleColors = [NSUIColor.systemGray.withAlphaComponent(0.75)]
        lineNote.drawCircleHoleEnabled = false
        lineNote.setDrawHighlightIndicators(false)
        lineNote.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineNote.drawCirclesEnabled = true
        lineNote.lineWidth = 0
        lineNote.highlightEnabled = false
        lineNote.axisDependency = YAxis.AxisDependency.right
        lineNote.valueFormatter = ChartYDataValueFormatter()
        lineNote.drawValuesEnabled = false

        // Setup COB Prediction line details
        var COBpredictionChartEntry = [ChartDataEntry]()
        let COBlinePrediction = LineChartDataSet(entries:COBpredictionChartEntry, label: "")
        COBlinePrediction.drawCirclesEnabled = false
        COBlinePrediction.setColor(NSUIColor.systemPurple)
        COBlinePrediction.highlightEnabled = true
        COBlinePrediction.drawHorizontalHighlightIndicatorEnabled = false
        COBlinePrediction.drawVerticalHighlightIndicatorEnabled = false
        COBlinePrediction.highlightColor = NSUIColor.label
        COBlinePrediction.drawValuesEnabled = false
        COBlinePrediction.lineWidth = 1.5
        COBlinePrediction.axisDependency = YAxis.AxisDependency.right

        // Setup IOB Prediction line details
        var IOBpredictionChartEntry = [ChartDataEntry]()
        let IOBlinePrediction = LineChartDataSet(entries:IOBpredictionChartEntry, label: "")
        IOBlinePrediction.drawCirclesEnabled = false
        IOBlinePrediction.setColor(NSUIColor.systemPurple)
        IOBlinePrediction.highlightEnabled = true
        IOBlinePrediction.drawHorizontalHighlightIndicatorEnabled = false
        IOBlinePrediction.drawVerticalHighlightIndicatorEnabled = false
        IOBlinePrediction.highlightColor = NSUIColor.label
        IOBlinePrediction.drawValuesEnabled = false
        IOBlinePrediction.lineWidth = 1.5
        IOBlinePrediction.axisDependency = YAxis.AxisDependency.right

        // Setup UAM Prediction line details
        var UAMpredictionChartEntry = [ChartDataEntry]()
        let UAMlinePrediction = LineChartDataSet(entries:UAMpredictionChartEntry, label: "")
        UAMlinePrediction.drawCirclesEnabled = false
        UAMlinePrediction.setColor(NSUIColor.systemPurple)
        UAMlinePrediction.highlightEnabled = true
        UAMlinePrediction.drawHorizontalHighlightIndicatorEnabled = false
        UAMlinePrediction.drawVerticalHighlightIndicatorEnabled = false
        UAMlinePrediction.highlightColor = NSUIColor.label
        UAMlinePrediction.drawValuesEnabled = false
        UAMlinePrediction.lineWidth = 1.5
        UAMlinePrediction.axisDependency = YAxis.AxisDependency.right

        // Setup ZT Prediction line details
        var ZTpredictionChartEntry = [ChartDataEntry]()
        let ZTlinePrediction = LineChartDataSet(entries:ZTpredictionChartEntry, label: "")
        ZTlinePrediction.drawCirclesEnabled = false
        ZTlinePrediction.setColor(NSUIColor.systemPurple)
        ZTlinePrediction.highlightEnabled = true
        ZTlinePrediction.drawHorizontalHighlightIndicatorEnabled = false
        ZTlinePrediction.drawVerticalHighlightIndicatorEnabled = false
        ZTlinePrediction.highlightColor = NSUIColor.label
        ZTlinePrediction.drawValuesEnabled = false
        ZTlinePrediction.lineWidth = 1.5
        ZTlinePrediction.axisDependency = YAxis.AxisDependency.right
        
        // SMB
        var chartEntrySmb = [ChartDataEntry]()
        let lineSmb = LineChartDataSet(entries:chartEntrySmb, label: "")
        lineSmb.circleRadius = 2
        lineSmb.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineSmb.drawCircleHoleEnabled = false
        lineSmb.setDrawHighlightIndicators(false)
        lineSmb.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineSmb.lineWidth = 0
        lineSmb.axisDependency = YAxis.AxisDependency.right
        lineSmb.valueFormatter = ChartYDataValueFormatter()
        lineSmb.valueTextColor = NSUIColor.label
        lineSmb.fillColor = NSUIColor.systemBlue
        lineSmb.fillAlpha = 0.6
        lineSmb.drawCirclesEnabled = true
        lineSmb.drawFilledEnabled = false
        lineSmb.drawValuesEnabled = false
        lineSmb.highlightEnabled = false
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.append(lineBG) // Dataset 0
        data.append(linePrediction) // Dataset 1
        data.append(lineBasal) // Dataset 2
        data.append(lineBolus) // Dataset 3
        data.append(lineCarbs) // Dataset 4
        data.append(lineBasalScheduled) // Dataset 5
        data.append(lineOverride) // Dataset 6
        data.append(lineBGCheck) // Dataset 7
        data.append(lineSuspend) // Dataset 8
        data.append(lineResume) // Dataset 9
        data.append(lineSensor) // Dataset 10
        data.append(lineNote) // Dataset 11
        data.append(ZTlinePrediction) // Dataset 12
        data.append(IOBlinePrediction) // Dataset 13
        data.append(COBlinePrediction) // Dataset 14
        data.append(UAMlinePrediction) // Dataset 15
        data.append(lineSmb) // Dataset 16

        BGChartFull.highlightPerDragEnabled = true
        BGChartFull.leftAxis.enabled = false
        BGChartFull.leftAxis.axisMaximum = maxBasal
        BGChartFull.leftAxis.axisMinimum = 0
        
        BGChartFull.rightAxis.enabled = false
        BGChartFull.rightAxis.axisMinimum = 0.0
        BGChartFull.rightAxis.axisMaximum = Double(maxBG)
                                               
        BGChartFull.xAxis.drawLabelsEnabled = false
        BGChartFull.xAxis.drawGridLinesEnabled = false
        BGChartFull.xAxis.drawAxisLineEnabled = false
        BGChartFull.legend.enabled = false
        BGChartFull.scaleYEnabled = false
        BGChartFull.scaleXEnabled = false
        BGChartFull.drawGridBackgroundEnabled = false
        BGChartFull.data = data
        
        
    }
    
    func updateOverrideGraph() {
        var dataIndex = 6
        var yTop: Double = Double(calculateMaxBgGraphValue() - 5)
        var yBottom: Double = Double(calculateMaxBgGraphValue() - 25)
        var chart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        chart.clear()
        smallChart.clear()
        let thisData = overrideGraphData
        
        var colors = [NSUIColor]()
        for i in 0..<thisData.count{
            let thisItem = thisData[i]
            let multiplier = thisItem.insulNeedsScaleFactor as! Double * 100.0
            var labelText = thisItem.reason + "\r\n"
            labelText += String(Int(thisItem.insulNeedsScaleFactor * 100)) + "% "
            if thisItem.correctionRange.count == 2 {
                labelText += String(thisItem.correctionRange[0]) + "-" + String(thisItem.correctionRange[1])
            }
            if thisItem.enteredBy.count > 0 {
                labelText += "\r\nEntered By: " + thisItem.enteredBy
            }
            
            
            // Start Dot
            // Shift dots 30 seconds to create an empty 0 space between consecutive temps
            let preStartDot = ChartDataEntry(x: Double(thisItem.date), y: yBottom, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(preStartDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(preStartDot)
            }
            
            let startDot = ChartDataEntry(x: Double(thisItem.date + 1), y: yTop, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(startDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(startDot)
            }

            // End Dot
            let endDot = ChartDataEntry(x: Double(thisItem.endDate - 2), y: yTop, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(endDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(endDot)
            }
            
            // Post end dot
            let postEndDot = ChartDataEntry(x: Double(thisItem.endDate - 1), y: yBottom, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(postEndDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(postEndDot)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func formatPillText(line1: String, time: TimeInterval, line2: String? = nil) -> String {
        let dateFormatter = DateFormatter()
        if dateTimeUtils.is24Hour() {
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
        }
        
        let date = Date(timeIntervalSince1970: time)
        let formattedDate = dateFormatter.string(from: date)
        
        if let line2 = line2 {
            return line1 + "\r\n" + line2 + "\r\n" + formattedDate
        } else {
            return line1 + "\r\n" + formattedDate
        }
    }
  
    func updatePredictionGraphGeneric(
        dataIndex: Int,
        predictionData: [ShareGlucoseData],
        chartLabel: String,
        color: UIColor
    ) {
        let mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        
        var colors = [NSUIColor]()
        let maxBGOffset: Float = 20
        
        for i in 0..<predictionData.count {
            let predictionVal = Double(predictionData[i].sgv)
            if Float(predictionVal) > topPredictionBG - maxBGOffset {
                topPredictionBG = Float(predictionVal) + maxBGOffset
            }
            
            if i == 0 {
                if UserDefaultsRepository.showDots.value {
                    colors.append((color).withAlphaComponent(0.0))
                } else {
                    colors.append((color).withAlphaComponent(1.0))
                }
            } else {
                colors.append(color)
            }
            
            let value = ChartDataEntry(
                x: predictionData[i].date,
                y: predictionVal,
                data: formatPillText(
                    line1: chartLabel,
                    time: predictionData[i].date,
                    line2: bgUnits.toDisplayUnits(String(predictionVal))
                )
            )
            mainChart.addEntry(value)
            smallChart.addEntry(value)
        }
        
        smallChart.circleColors.removeAll()
        smallChart.colors.removeAll()
        mainChart.colors.removeAll()
        mainChart.circleColors.removeAll()
        if colors.count > 0 {
            for color in colors {
                mainChart.addColor(color)
                mainChart.circleColors.append(color)
                smallChart.addColor(color)
                smallChart.circleColors.append(color)
            }
        }
        
        BGChart.rightAxis.axisMaximum = Double(calculateMaxBgGraphValue())
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChartFull.data?.notifyDataChanged()
        BGChartFull.notifyDataSetChanged()
    }
}
