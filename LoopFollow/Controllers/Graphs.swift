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

let ScaleXMax:Float = 150.0

let lineBG = LineChartDataSet(entries:[ChartDataEntry](), label: "BG")
let lineBasal = LineChartDataSet(entries:[ChartDataEntry](), label: "Temp. Basal")
let linePrediction = LineChartDataSet(entries:[ChartDataEntry](), label: "Prediction")
let lineBolus = LineChartDataSet(entries:[ChartDataEntry](), label: "Bolus")
let lineCarbs = LineChartDataSet(entries:[ChartDataEntry](), label: "Carbs")
let lineBasalScheduled = LineChartDataSet(entries:[ChartDataEntry](), label: "Basal")
let lineOverride = LineChartDataSet(entries:[ChartDataEntry](), label: "Override")
let lineBGCheck = LineChartDataSet(entries:[ChartDataEntry](), label: "BG Check")
let lineSuspend = LineChartDataSet(entries:[ChartDataEntry](), label: "Suspend")
let lineResume = LineChartDataSet(entries:[ChartDataEntry](), label: "Resume")
let lineSensor = LineChartDataSet(entries:[ChartDataEntry](), label: "Sensor")
let lineNote = LineChartDataSet(entries:[ChartDataEntry](), label: "Note")

let lineSmallBG = LineChartDataSet(entries:[ChartDataEntry](), label: "S BG")
let lineSmallPrediction = LineChartDataSet(entries:[ChartDataEntry](), label: "S Prediction")
let lineSmallBasal = LineChartDataSet(entries:[ChartDataEntry](), label: "S Temp. Basal")
let lineSmallBolus = LineChartDataSet(entries:[ChartDataEntry](), label: "S Bolus")
let lineSmallCarbs = LineChartDataSet(entries:[ChartDataEntry](), label: "S Carbs")
let lineSmallBasalScheduled = LineChartDataSet(entries:[ChartDataEntry](), label: "S Basal")
let lineSmallOverride = LineChartDataSet(entries:[ChartDataEntry](), label: "S Override")
let lineSmallBGCheck = LineChartDataSet(entries:[ChartDataEntry](), label: "S BG Check")
let lineSmallSuspend = LineChartDataSet(entries:[ChartDataEntry](), label: "S Suspend")
let lineSmallResume = LineChartDataSet(entries:[ChartDataEntry](), label: "S Resume")
let lineSmallSensor = LineChartDataSet(entries:[ChartDataEntry](), label: "S Sensor")
let lineSmallNote = LineChartDataSet(entries:[ChartDataEntry](), label: "S Note")

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
        // dont store huge values
        var scale: Float = Float(BGChart.scaleX)
        if(scale > ScaleXMax ) {
            scale = ScaleXMax
        }
        UserDefaultsRepository.chartScaleX.value = scale
    }

    func createGraph() {
        BGChart.clear()
        
        lineBG.circleRadius = CGFloat(globalVariables.dotBG)
        lineBG.circleColors = [NSUIColor.systemGreen]
        lineBG.drawCircleHoleEnabled = false
        lineBG.axisDependency = YAxis.AxisDependency.right
        lineBG.highlightEnabled = true
        lineBG.drawValuesEnabled = false
        lineBG.lineWidth = UserDefaultsRepository.showLines.value ? 2 : 0
        lineBG.drawCirclesEnabled = UserDefaultsRepository.showDots.value
        lineBG.setDrawHighlightIndicators(false)
        lineBG.valueFont.withSize(50)
        
        linePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        linePrediction.circleColors = [NSUIColor.systemPurple]
        linePrediction.colors = [NSUIColor.systemPurple]
        linePrediction.drawCircleHoleEnabled = false
        linePrediction.axisDependency = YAxis.AxisDependency.right
        linePrediction.highlightEnabled = true
        linePrediction.drawValuesEnabled = false
        linePrediction.lineWidth = UserDefaultsRepository.showLines.value ? 2 : 0
        linePrediction.drawCirclesEnabled = UserDefaultsRepository.showDots.value
        linePrediction.setDrawHighlightIndicators(false)
        linePrediction.valueFont.withSize(50)

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
        lineBolus.drawValuesEnabled = UserDefaultsRepository.showValues.value
        lineBolus.highlightEnabled = !UserDefaultsRepository.showValues.value

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
        lineCarbs.drawValuesEnabled = UserDefaultsRepository.showValues.value
        lineCarbs.highlightEnabled = !UserDefaultsRepository.showValues.value

        lineBasalScheduled.setDrawHighlightIndicators(false)
        lineBasalScheduled.setColor(NSUIColor.systemBlue, alpha: 0.8)
        lineBasalScheduled.lineWidth = 2
        lineBasalScheduled.drawFilledEnabled = false
        lineBasalScheduled.drawCirclesEnabled = false
        lineBasalScheduled.axisDependency = YAxis.AxisDependency.left
        lineBasalScheduled.highlightEnabled = false
        lineBasalScheduled.drawValuesEnabled = false
        lineBasalScheduled.lineDashLengths = [10.0, 5.0]

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
//        lineOverride.circleColors = [NSUIColor.systemGreen.withAlphaComponent(0.75)]
//        lineOverride.valueFormatter = ChartYDataValueFormatter()
//        lineOverride.drawCircleHoleEnabled = false
        
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
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.addDataSet(lineBG)
        data.addDataSet(linePrediction)
        data.addDataSet(lineBasal)
        data.addDataSet(lineBolus)
        data.addDataSet(lineCarbs)
        data.addDataSet(lineBasalScheduled)
        data.addDataSet(lineOverride)
        data.addDataSet(lineBGCheck)
        data.addDataSet(lineSuspend)
        data.addDataSet(lineResume)
        data.addDataSet(lineSensor)
        data.addDataSet(lineNote)
        
        data.setValueFont(UIFont.systemFont(ofSize: 12))
        
        // Add marker popups for bolus and carbs
        BGChart.marker = PillMarker(color: .secondarySystemBackground, font: UIFont.boldSystemFont(ofSize: 14), textColor: .label)
        
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
        BGChart.leftAxis.axisMaximum = UserDefaultsRepository.minBasalScale.value
        BGChart.leftAxis.axisMinimum = 0
        BGChart.leftAxis.drawGridLinesEnabled = false
        BGChart.leftAxis.granularityEnabled = true
        BGChart.leftAxis.granularity = 0.5
        
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 0.0
        BGChart.rightAxis.axisMaximum = UserDefaultsRepository.minBGScale.value
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
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
    }
    
    func createSmallBGGraph(){
        let maxBG = UserDefaultsRepository.minBGScale.value
        let maxBasal = UserDefaultsRepository.minBasalScale.value

        lineSmallBG.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        lineSmallBG.highlightEnabled = true
        lineSmallBG.drawHorizontalHighlightIndicatorEnabled = false
        lineSmallBG.drawVerticalHighlightIndicatorEnabled = false
        lineSmallBG.highlightColor = NSUIColor.label
        lineSmallBG.drawValuesEnabled = false
        lineSmallBG.lineWidth = 1.5
        lineSmallBG.axisDependency = YAxis.AxisDependency.right
        
        // Setup Prediction line details
        lineSmallPrediction.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        lineSmallPrediction.setColor(NSUIColor.systemPurple)
        lineSmallPrediction.highlightEnabled = true
        lineSmallPrediction.drawHorizontalHighlightIndicatorEnabled = false
        lineSmallPrediction.drawVerticalHighlightIndicatorEnabled = false
        lineSmallPrediction.highlightColor = NSUIColor.label
        lineSmallPrediction.drawValuesEnabled = false
        lineSmallPrediction.lineWidth = 1.5
        lineSmallPrediction.axisDependency = YAxis.AxisDependency.right
        
        lineSmallBasal.setDrawHighlightIndicators(false)
        lineSmallBasal.setColor(NSUIColor.systemBlue, alpha: 0.5)
        lineSmallBasal.lineWidth = 0
        lineSmallBasal.drawFilledEnabled = true
        lineSmallBasal.fillColor = NSUIColor.systemBlue
        lineSmallBasal.fillAlpha = 0.35
        lineSmallBasal.drawCirclesEnabled = false
        lineSmallBasal.axisDependency = YAxis.AxisDependency.left
        lineSmallBasal.highlightEnabled = false
        lineSmallBasal.drawValuesEnabled = false
        lineSmallBasal.fillFormatter = basalFillFormatter()
        
        lineSmallBolus.circleRadius = 2
        lineSmallBolus.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineSmallBolus.drawCircleHoleEnabled = false
        lineSmallBolus.setDrawHighlightIndicators(false)
        lineSmallBolus.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineSmallBolus.lineWidth = 0
        lineSmallBolus.axisDependency = YAxis.AxisDependency.right
        lineSmallBolus.valueFormatter = ChartYDataValueFormatter()
        lineSmallBolus.valueTextColor = NSUIColor.label
        lineSmallBolus.fillColor = NSUIColor.systemBlue
        lineSmallBolus.fillAlpha = 0.6
        lineSmallBolus.drawCirclesEnabled = true
        lineSmallBolus.drawFilledEnabled = false
        lineSmallBolus.drawValuesEnabled = false
        lineSmallBolus.highlightEnabled = false

        lineSmallCarbs.circleRadius = 2
        lineSmallCarbs.circleColors = [NSUIColor.systemOrange.withAlphaComponent(0.75)]
        lineSmallCarbs.drawCircleHoleEnabled = false
        lineSmallCarbs.setDrawHighlightIndicators(false)
        lineSmallCarbs.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineSmallCarbs.lineWidth = 0
        lineSmallCarbs.axisDependency = YAxis.AxisDependency.right
        lineSmallCarbs.valueFormatter = ChartYDataValueFormatter()
        lineSmallCarbs.valueTextColor = NSUIColor.label
        lineSmallCarbs.fillColor = NSUIColor.systemOrange
        lineSmallCarbs.fillAlpha = 0.6
        lineSmallCarbs.drawCirclesEnabled = true
        lineSmallCarbs.drawFilledEnabled = false
        lineSmallCarbs.drawValuesEnabled = false
        lineSmallCarbs.highlightEnabled = false

        lineSmallBasalScheduled.setDrawHighlightIndicators(false)
        lineSmallBasalScheduled.setColor(NSUIColor.systemBlue, alpha: 0.8)
        lineSmallBasalScheduled.lineWidth = 0.5
        lineSmallBasalScheduled.drawFilledEnabled = false
        lineSmallBasalScheduled.drawCirclesEnabled = false
        lineSmallBasalScheduled.axisDependency = YAxis.AxisDependency.left
        lineSmallBasalScheduled.highlightEnabled = false
        lineSmallBasalScheduled.drawValuesEnabled = false
        lineSmallBasalScheduled.lineDashLengths = [2, 1]
        
        lineSmallOverride.setDrawHighlightIndicators(false)
        lineSmallOverride.lineWidth = 0
        lineSmallOverride.drawFilledEnabled = true
        lineSmallOverride.fillFormatter = OverrideFillFormatter()
        lineSmallOverride.fillColor = NSUIColor.systemGreen
        lineSmallOverride.fillAlpha = 0.6
        lineSmallOverride.drawCirclesEnabled = false
        lineSmallOverride.axisDependency = YAxis.AxisDependency.right
        lineSmallOverride.highlightEnabled = true
        lineSmallOverride.drawValuesEnabled = false
        
        lineSmallBGCheck.circleRadius = 2
        lineSmallBGCheck.circleColors = [NSUIColor.systemRed.withAlphaComponent(0.75)]
        lineSmallBGCheck.drawCircleHoleEnabled = false
        lineSmallBGCheck.setDrawHighlightIndicators(false)
        lineSmallBGCheck.setColor(NSUIColor.systemRed, alpha: 1.0)
        lineSmallBGCheck.drawCirclesEnabled = true
        lineSmallBGCheck.lineWidth = 0
        lineSmallBGCheck.highlightEnabled = false
        lineSmallBGCheck.axisDependency = YAxis.AxisDependency.right
        lineSmallBGCheck.valueFormatter = ChartYDataValueFormatter()
        lineSmallBGCheck.drawValuesEnabled = false
        
        lineSmallSuspend.circleRadius = 2
        lineSmallSuspend.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineSmallSuspend.drawCircleHoleEnabled = false
        lineSmallSuspend.setDrawHighlightIndicators(false)
        lineSmallSuspend.setColor(NSUIColor.systemGray2, alpha: 1.0)
        lineSmallSuspend.drawCirclesEnabled = true
        lineSmallSuspend.lineWidth = 0
        lineSmallSuspend.highlightEnabled = false
        lineSmallSuspend.axisDependency = YAxis.AxisDependency.right
        lineSmallSuspend.valueFormatter = ChartYDataValueFormatter()
        lineSmallSuspend.drawValuesEnabled = false
        
        lineSmallResume.circleRadius = 2
        lineSmallResume.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineSmallResume.drawCircleHoleEnabled = false
        lineSmallResume.setDrawHighlightIndicators(false)
        lineSmallResume.setColor(NSUIColor.systemGray4, alpha: 1.0)
        lineSmallResume.drawCirclesEnabled = true
        lineSmallResume.lineWidth = 0
        lineSmallResume.highlightEnabled = false
        lineSmallResume.axisDependency = YAxis.AxisDependency.right
        lineSmallResume.valueFormatter = ChartYDataValueFormatter()
        lineSmallResume.drawValuesEnabled = false
        
        lineSmallSensor.circleRadius = 2
        lineSmallSensor.circleColors = [NSUIColor.systemIndigo.withAlphaComponent(0.75)]
        lineSmallSensor.drawCircleHoleEnabled = false
        lineSmallSensor.setDrawHighlightIndicators(false)
        lineSmallSensor.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineSmallSensor.drawCirclesEnabled = true
        lineSmallSensor.lineWidth = 0
        lineSmallSensor.highlightEnabled = false
        lineSmallSensor.axisDependency = YAxis.AxisDependency.right
        lineSmallSensor.valueFormatter = ChartYDataValueFormatter()
        lineSmallSensor.drawValuesEnabled = false
        
        lineSmallNote.circleRadius = 2
        lineSmallNote.circleColors = [NSUIColor.systemGray.withAlphaComponent(0.75)]
        lineSmallNote.drawCircleHoleEnabled = false
        lineSmallNote.setDrawHighlightIndicators(false)
        lineSmallNote.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineSmallNote.drawCirclesEnabled = true
        lineSmallNote.lineWidth = 0
        lineSmallNote.highlightEnabled = false
        lineSmallNote.axisDependency = YAxis.AxisDependency.right
        lineSmallNote.valueFormatter = ChartYDataValueFormatter()
        lineSmallNote.drawValuesEnabled = false
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.addDataSet(lineSmallBG)
        data.addDataSet(lineSmallPrediction)
        data.addDataSet(lineSmallBasal)
        data.addDataSet(lineSmallBolus)
        data.addDataSet(lineSmallCarbs)
        data.addDataSet(lineSmallBasalScheduled)
        data.addDataSet(lineSmallOverride)
        data.addDataSet(lineSmallBGCheck)
        data.addDataSet(lineSmallSuspend)
        data.addDataSet(lineSmallResume)
        data.addDataSet(lineSmallSensor)
        data.addDataSet(lineSmallNote)
        
        BGChartFull.highlightPerDragEnabled = true
        BGChartFull.leftAxis.enabled = false
        BGChartFull.leftAxis.axisMinimum = 0.0
        BGChartFull.leftAxis.axisMaximum = maxBasal
        
        BGChartFull.rightAxis.enabled = false
        BGChartFull.rightAxis.axisMinimum = 0.0
        BGChartFull.rightAxis.axisMaximum = maxBG
                                               
        BGChartFull.xAxis.drawLabelsEnabled = false
        BGChartFull.xAxis.drawGridLinesEnabled = false
        BGChartFull.xAxis.drawAxisLineEnabled = false
        BGChartFull.legend.enabled = false
        BGChartFull.scaleYEnabled = false
        BGChartFull.scaleXEnabled = false
        BGChartFull.drawGridBackgroundEnabled = false
        BGChartFull.data = data
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
    }
    
    func createMidnightLines() {
        // Draw a line at midnight: useful when showing multiple days of data
        if UserDefaultsRepository.showMidnightLines.value {
            var midnightTimeInterval = dateTimeUtils.getTimeIntervalMidnightToday()
            let graphStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * UserDefaultsRepository.downloadDays.value)
            while midnightTimeInterval > graphStart {
                // Large chart
                let ul = ChartLimitLine()
                ul.limit = Double(midnightTimeInterval)
                ul.lineColor = NSUIColor.systemTeal
                ul.lineDashLengths = [CGFloat(2), CGFloat(5)]
                ul.lineWidth = 2
                BGChart.xAxis.addLimitLine(ul)

                if UserDefaultsRepository.showSmallGraph.value {
                    // Small chart
                    let sl = ChartLimitLine()
                    sl.limit = Double(midnightTimeInterval)
                    sl.lineColor = NSUIColor.systemTeal
                    sl.lineDashLengths = [CGFloat(2), CGFloat(2)]
                    sl.lineWidth = 2
                    BGChartFull.xAxis.addLimitLine(sl)
                }
                
                midnightTimeInterval = midnightTimeInterval.advanced(by: -24*60*60)
            }
        }
    }
    
    func updateBGGraphSettings() {

        if UserDefaultsRepository.showLines.value {
            lineBG.lineWidth = 2
            linePrediction.lineWidth = 2
        } else {
            lineBG.lineWidth = 0
            linePrediction.lineWidth = 0
        }
        lineBG.drawCirclesEnabled = UserDefaultsRepository.showDots.value
        linePrediction.drawCirclesEnabled = UserDefaultsRepository.showDots.value

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
    
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateBGGraph() {
        writeDebugLog(value: "##### start BG graph #####")

        if bgData.count < 1 { return }

        lineBG.removeAll(keepingCapacity: true)
        lineSmallBG.removeAll(keepingCapacity: true)

        let maxBGOffset: Double = 50
        
        var colors = [NSUIColor]()
        for entry in bgData {
            if topBG < Double(entry.sgv) + maxBGOffset {
                topBG = Double(entry.sgv) + maxBGOffset
            }
            let value = ChartDataEntry(x: Double(entry.date), y: Double(entry.sgv), data: formatPillText(line1: bgUnits.toDisplayUnits(String(entry.sgv)), time: entry.date))
            lineBG.append(value)
            if UserDefaultsRepository.showSmallGraph.value {
                lineSmallBG.append(value)
            }
            
            if Double(entry.sgv) >= Double(UserDefaultsRepository.highLine.value) {
                colors.append(NSUIColor.systemYellow)
            } else if Double(entry.sgv) <= Double(UserDefaultsRepository.lowLine.value) {
               colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        // Set Colors
        lineBG.colors.removeAll()
        lineBG.circleColors.removeAll()
        if UserDefaultsRepository.showSmallGraph.value {
            lineSmallBG.colors.removeAll()
            lineSmallBG.circleColors.removeAll()
        }
        for color in colors {
            lineBG.addColor(color)
            lineBG.circleColors.append(color)
            if UserDefaultsRepository.showSmallGraph.value {
                lineSmallBG.addColor(color)
                lineSmallBG.circleColors.append(color)
            }
        }
        
        BGChart.rightAxis.axisMaximum = Double(topBG)
        BGChart.setVisibleXRangeMinimum(600)
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()

        if UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.rightAxis.axisMaximum = Double(topBG)
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }

        if firstGraphLoad {
            var scaleX = CGFloat(UserDefaultsRepository.chartScaleX.value)
            print("Scale: \(scaleX)")
            if( scaleX > CGFloat(ScaleXMax) ) {
                scaleX = CGFloat(ScaleXMax)
                UserDefaultsRepository.chartScaleX.value = ScaleXMax
            }
            BGChart.zoom(scaleX: scaleX, scaleY: 1, x: 1, y: 1)
            BGChart.moveViewToAnimated(xValue: dateTimeUtils.getNowTimeIntervalUTC() - (BGChart.visibleXRange * 0.7), yValue: 0.0, axis: .right, duration: 1, easingOption: .easeInBack)
            firstGraphLoad = false
        }
        
        // Move to current reading everytime new readings load
        // BGChart.moveViewToAnimated(xValue: dateTimeUtils.getNowTimeIntervalUTC() - (BGChart.visibleXRange * 0.7), yValue: 0.0, axis: .right, duration: 1, easingOption: .easeInBack)
    }
    
    func updatePredictionGraph() {
        writeDebugLog(value: "##### start prediction graph #####")

        linePrediction.removeAll(keepingCapacity: true)
        lineSmallPrediction.removeAll(keepingCapacity: true)

        var colors = [NSUIColor]()
        let maxBGOffset: Double = 20
        for i in 0..<predictionData.count {
            var predictionVal = Double(predictionData[i].sgv)
            if predictionVal + maxBGOffset > topBG  {
                topBG = predictionVal + maxBGOffset
            }

            if i == 0 {
                if UserDefaultsRepository.showDots.value {
                    colors.append(NSUIColor.systemPurple.withAlphaComponent(0.0))
                } else {
                    colors.append(NSUIColor.systemPurple.withAlphaComponent(1.0))
                }
            } else if predictionVal > 400 {
                predictionVal = 400
                colors.append(NSUIColor.systemYellow)
            } else if predictionVal < 0 {
                predictionVal = 0
                colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemPurple)
            }
            let value = ChartDataEntry(
                x: predictionData[i].date,
                y: Double(predictionVal),
                data: formatPillText(
                    line1: bgUnits.toDisplayUnits(String(predictionData[i].sgv)),
                    time: predictionData[i].date
                )
            )
            linePrediction.append(value)
            if UserDefaultsRepository.showSmallGraph.value {
                lineSmallPrediction.append(value)
            }
        }
        
        linePrediction.colors.removeAll()
        linePrediction.circleColors.removeAll()

        if UserDefaultsRepository.showSmallGraph.value {
            lineSmallPrediction.circleColors.removeAll()
            lineSmallPrediction.colors.removeAll()
        }
        if colors.count > 0 {
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Graph: prediction colors") }
            for i in 0..<colors.count{
                linePrediction.addColor(colors[i])
                linePrediction.circleColors.append(colors[i])
                if UserDefaultsRepository.showSmallGraph.value {
                    lineSmallPrediction.addColor(colors[i])
                    lineSmallPrediction.circleColors.append(colors[i])
                }
            }
        }
        BGChart.rightAxis.axisMaximum = Double(topBG)
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateBasalGraph() {
        writeDebugLog(value: "##### start basal graph #####")

        lineBasal.removeAll(keepingCapacity: true)
        lineSmallBasal.removeAll(keepingCapacity: true)
        
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        var maxBasalSmall: Double = 0.0
        for i in 0..<basalData.count{
            let value = ChartDataEntry(x: Double(basalData[i].date), y: Double(basalData[i].basalRate), data: formatPillText(line1: String(basalData[i].basalRate), time: basalData[i].date))
            lineBasal.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                lineSmallBasal.append(value)
            }
            if basalData[i].basalRate  > maxBasal {
                maxBasal = basalData[i].basalRate
            }
            if basalData[i].basalRate > maxBasalSmall {
                maxBasalSmall = basalData[i].basalRate
            }
        }
        
        BGChart.leftAxis.axisMaximum = maxBasal
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()

        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.leftAxis.axisMaximum = maxBasalSmall
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBasalScheduledGraph() {
        writeDebugLog(value: "##### start scheduled basal graph #####")

        lineBasalScheduled.removeAll(keepingCapacity: true)
        lineSmallBasalScheduled.removeAll(keepingCapacity: true)

        for data in basalScheduleData {
            
            let value = ChartDataEntry(x: Double(data.date), y: Double(data.basalRate))
            lineBasalScheduled.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallBasalScheduled.append(value)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBolusGraph() {
        writeDebugLog(value: "##### start bolus graph #####")

        lineBolus.removeAll(keepingCapacity: true)
        lineSmallBolus.removeAll(keepingCapacity: true)
        
        var colors = [NSUIColor]()
        for i in 0..<bolusData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 0
            
            // Check overlapping carbs to shift left if needed
            let bolusShift = findNextBolusTime(timeWithin: 240, needle: bolusData[i].date, haystack: bolusData, startingIndex: i)
            var dateTimeStamp = bolusData[i].date
            
            // Alpha colors for DIA
            let nowTime = dateTimeUtils.getNowTimeIntervalUTC()
            let diffTimeHours = (nowTime - dateTimeStamp) / 60 / 60
            if diffTimeHours <= 1 {
                colors.append(NSUIColor.systemBlue.withAlphaComponent(1.0))
            } else if diffTimeHours > 6 {
                colors.append(NSUIColor.systemBlue.withAlphaComponent(0.25))
            } else {
                let thisAlpha = 1.0 - (0.15 * diffTimeHours)
                colors.append(NSUIColor.systemBlue.withAlphaComponent(CGFloat(thisAlpha)))
            }
            
            if bolusShift {
                // Move it half the distance between BG readings
                dateTimeStamp = dateTimeStamp - 150
            }
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
  
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(bolusData[i].sgv), data: formatter.string(from: NSNumber(value: bolusData[i].value)))
            lineBolus.append(dot)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallBolus.append(dot)
            }
        }
        
        // Set Colors
        lineBolus.colors.removeAll()
        lineBolus.circleColors.removeAll()
        lineSmallBolus.colors.removeAll()
        lineSmallBolus.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                lineBolus.addColor(colors[i])
                lineBolus.circleColors.append(colors[i])
                if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                    lineSmallBolus.addColor(colors[i])
                    lineSmallBolus.circleColors.append(colors[i])
                }
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateCarbGraph() {
        writeDebugLog(value: "##### start carb graph #####")

        lineCarbs.removeAll(keepingCapacity: true)
        lineSmallCarbs.removeAll(keepingCapacity: true)
        
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
            
            // Alpha colors for DIA
            let nowTime = dateTimeUtils.getNowTimeIntervalUTC()
            let diffTimeHours = (nowTime - dateTimeStamp) / 60 / 60
            if diffTimeHours <= 0.5 {
                colors.append(NSUIColor.systemOrange.withAlphaComponent(1.0))
            } else if diffTimeHours > Double(hours) {
                colors.append(NSUIColor.systemOrange.withAlphaComponent(0.25))
            } else {
                let thisAlpha = 1.0 - ((0.75 / Double(hours)) * diffTimeHours)
                colors.append(NSUIColor.systemOrange.withAlphaComponent(CGFloat(thisAlpha)))
            }
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            if carbShift {
                dateTimeStamp = dateTimeStamp - 250
            }

            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(carbData[i].sgv), data: valueString)
            lineCarbs.append(dot)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallCarbs.append(dot)
            }
        }
        
        lineCarbs.colors.removeAll()
        lineCarbs.circleColors.removeAll()
        lineSmallCarbs.colors.removeAll()
        lineSmallCarbs.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                lineCarbs.addColor(colors[i])
                lineCarbs.circleColors.append(colors[i])
                if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                    lineSmallCarbs.addColor(colors[i])
                    lineSmallCarbs.circleColors.append(colors[i])
                }
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBGCheckGraph() {
        writeDebugLog(value: "##### start BG check graph #####")

        lineBGCheck.removeAll(keepingCapacity: true)
        lineSmallBGCheck.removeAll(keepingCapacity: true)
        
        let startOfGraph: TimeInterval = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * UserDefaultsRepository.downloadDays.value)

        for data in bgCheckData {
            // skip if outside of visible area
            if data.date < startOfGraph { continue }
            
            let value = ChartDataEntry(x: Double(data.date), y: Double(data.sgv), data: formatPillText(line1: bgUnits.toDisplayUnits(String(data.sgv)), time: data.date))
            lineBGCheck.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallBGCheck.append(value)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSuspendGraph() {
        writeDebugLog(value: "##### start suspend graph #####")

        lineSuspend.removeAll(keepingCapacity: true)
        lineSmallSuspend.removeAll(keepingCapacity: true)

        let startOfGraph: TimeInterval = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * UserDefaultsRepository.downloadDays.value)

        for data in suspendGraphData {
            // skip if outside of visible area
            if data.date < startOfGraph { continue }
            
            let value = ChartDataEntry(x: Double(data.date), y: Double(data.sgv), data: formatPillText(line1: "Suspend Pump", time: data.date))
            lineSuspend.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallSuspend.append(value)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateResumeGraph() {
        writeDebugLog(value: "##### start resume graph #####")

        lineResume.removeAll(keepingCapacity: true)
        lineSmallResume.removeAll(keepingCapacity: true)

        let startOfGraph: TimeInterval = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * UserDefaultsRepository.downloadDays.value)

        for data in resumeGraphData {
            // skip if outside of visible area
            if data.date < startOfGraph { continue }
            
            let value = ChartDataEntry(x: Double(data.date), y: Double(data.sgv), data: formatPillText(line1: "Resume Pump", time: data.date))
            lineResume.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallResume.append(value)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSensorStart() {
        writeDebugLog(value: "##### start sensor graph #####")

        lineSensor.removeAll(keepingCapacity: true)
        lineSmallSensor.removeAll(keepingCapacity: true)
        
        let startOfGraph = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * UserDefaultsRepository.downloadDays.value)

        for data in sensorStartGraphData {
            // skip if outside of visible area
            if data.date < startOfGraph { continue }
            
            let value = ChartDataEntry(x: Double(data.date), y: Double(data.sgv), data: formatPillText(line1: "Start Sensor", time: data.date))
            lineSensor.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallSensor.append(value)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateNotes() {
        writeDebugLog(value: "##### start notes graph #####")

        lineNote.removeAll(keepingCapacity: true)
        lineSmallNote.removeAll(keepingCapacity: true)

        let startOfGraph = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * UserDefaultsRepository.downloadDays.value)

        for data in noteGraphData {
            
            // skip if outside of visible area
            if data.date < startOfGraph { continue }
            
            let value = ChartDataEntry(x: Double(data.date), y: Double(data.sgv), data: formatPillText(line1: data.note, time: data.date))
            lineSmallNote.append(value)
            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallNote.append(value)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
 
    func updateOverrideGraph() {
        let yTop: Double = Double(topBG - 5)
        let yBottom: Double = Double(topBG - 25)

        lineOverride.removeAll(keepingCapacity: true)
        lineSmallOverride.removeAll(keepingCapacity: true)
        
        let thisData = overrideGraphData
        
        for thisItem in thisData {
            var labelText = thisItem.reason + "\n" + String(Int(Int(thisItem.insulNeedsScaleFactor * 100.0))) + " %"
            if thisItem.correctionRange.count == 2 {
                labelText += " " + String(thisItem.correctionRange[0]) + "-" + String(thisItem.correctionRange[1])
            }
            if !thisItem.enteredBy.isEmpty {
                labelText += "\nEntered By: " + thisItem.enteredBy
            }

            let preStartDot = ChartDataEntry(x: thisItem.date, y: yBottom, data: labelText)
            let startDot = ChartDataEntry(x: thisItem.date + 1, y: yTop, data: labelText)
            let endDot = ChartDataEntry(x: thisItem.endDate - 2, y: yTop, data: labelText)
            let postEndDot = ChartDataEntry(x: thisItem.endDate - 1, y: yBottom, data: labelText)

            lineOverride.append(preStartDot)
            lineOverride.append(startDot)
            lineOverride.append(endDot)
            lineOverride.append(postEndDot)

            if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
                lineSmallOverride.append(preStartDot)
                lineSmallOverride.append(startDot)
                lineSmallOverride.append(endDot)
                lineSmallOverride.append(postEndDot)
            }
        }
        
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value && UserDefaultsRepository.showSmallGraph.value {
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    

    func formatPillText(line1: String, time: TimeInterval) -> String {
        let dateFormatter = DateFormatter()
        //let timezoneOffset = TimeZone.current.secondsFromGMT()
        //let epochTimezoneOffset = value + Double(timezoneOffset)
        if dateTimeUtils.is24Hour() {
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
        }
        
        let date = Date(timeIntervalSince1970: time)
        let formattedDate = dateFormatter.string(from: date)

        return line1 + "\n" + formattedDate
    }
  
}
