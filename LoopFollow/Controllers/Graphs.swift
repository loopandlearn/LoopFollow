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
extension MainViewController {
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if chartView == BGChartFull {
            BGChart.moveViewToX(entry.x)
        }
        if entry.data as? String == "hide"{
            BGChart.highlightValue(nil, callDelegate: false)
        }
    }
    
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        if chartView == BGChart {
            let currentMatrix = chartView.viewPortHandler.touchMatrix
            //BGChartFull.viewPortHandler.refresh(newMatrix: currentMatrix, chart: BGChartFull, invalidate: true)
            //BGChartFull.highlightValue(x: Double(currentMatrix.tx), y: Double(currentMatrix.ty), dataSetIndex: 0)
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
        self.BGChart.clear()
        
        // Create the BG Graph Data
        let entries = bgData
        var bgChartEntry = [ChartDataEntry]()
        var colors = [NSUIColor]()
        var maxBG: Float = UserDefaultsRepository.minBGScale.value
        
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
        var predictionChartEntry = [ChartDataEntry]()
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
        var chartEntry = [ChartDataEntry]()
        var maxBasal = UserDefaultsRepository.minBasalScale.value
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
        var chartEntryBolus = [ChartDataEntry]()
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
        lineBolus.fillFormatter = BolusFillFormatter()
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
        var chartEntryCarbs = [ChartDataEntry]()
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
        lineCarbs.fillFormatter = CarbFillFormatter()
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
        var chartBasalScheduledEntry = [ChartDataEntry]()
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
        var chartEntrySuspend = [ChartDataEntry]()
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
        var chartEntryResume = [ChartDataEntry]()
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
        var chartEntrySensor = [ChartDataEntry]()
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
        var chartEntryNote = [ChartDataEntry]()
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
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.addDataSet(lineBG) // Dataset 0
        data.addDataSet(linePrediction) // Dataset 1
        data.addDataSet(lineBasal) // Dataset 2
        data.addDataSet(lineBolus) // Dataset 3
        data.addDataSet(lineCarbs) // Dataset 4
        data.addDataSet(lineBasalScheduled) // Dataset 5
        data.addDataSet(lineOverride) // Dataset 6
        data.addDataSet(lineBGCheck) // Dataset 7
        data.addDataSet(lineSuspend) // Dataset 8
        data.addDataSet(lineResume) // Dataset 9
        data.addDataSet(lineSensor) // Dataset 10
        data.addDataSet(lineNote) // Dataset 11
        
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
        
        // Add Now Line
        createNowLine()
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
        //BGChart.leftAxis.inverted = true
        
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 0.0
        BGChart.rightAxis.axisMaximum = Double(maxBG)
        BGChart.rightAxis.gridLineDashLengths = [5.0, 5.0]
        BGChart.rightAxis.drawGridLinesEnabled = false
        BGChart.rightAxis.valueFormatter = ChartYMMOLValueFormatter()
        BGChart.rightAxis.granularityEnabled = true
        BGChart.rightAxis.granularity = 50
        
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.drawGridBackgroundEnabled = true
        BGChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        
        BGChart.highlightValue(nil, callDelegate: false)
        
        BGChart.data = data
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        
    }
    
    func createNowLine() {
        BGChart.xAxis.removeAllLimitLines()
        let ul = ChartLimitLine()
        ul.limit = Double(dateTimeUtils.getNowTimeIntervalUTC())
        ul.lineColor = NSUIColor.systemGray.withAlphaComponent(0.5)
        ul.lineWidth = 1
        BGChart.xAxis.addLimitLine(ul)
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
    
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        
    }
    
    func updateBGGraph() {
        let dataIndex = 0
        let entries = bgData
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        var maxBGOffset: Float = 50
        
        var colors = [NSUIColor]()
        for i in 0..<entries.count{
            if Float(entries[i].sgv) > topBG - maxBGOffset {
                topBG = Float(entries[i].sgv) + maxBGOffset
            }
            let value = ChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].sgv), data: bgUnits.toDisplayUnits(String(entries[i].sgv)))
            mainChart.addEntry(value)
            smallChart.addEntry(value)
            
            if Double(entries[i].sgv) >= Double(UserDefaultsRepository.highLine.value) {
                colors.append(NSUIColor.systemYellow)
            } else if Double(entries[i].sgv) <= Double(UserDefaultsRepository.lowLine.value) {
               colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        
        // Set Colors
        let lineBG = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet

        let lineBGSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineBG.colors.removeAll()
        lineBG.circleColors.removeAll()
        lineBGSmall.colors.removeAll()
        lineBGSmall.circleColors.removeAll()

        if colors.count > 0 {
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Graph: colors") }
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        BGChart.rightAxis.axisMaximum = Double(topBG)
        BGChart.setVisibleXRangeMinimum(600)
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
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
        if BGChart.chartXMax > dateTimeUtils.getNowTimeIntervalUTC() {
            BGChart.moveViewToAnimated(xValue: dateTimeUtils.getNowTimeIntervalUTC() - (BGChart.visibleXRange * 0.7), yValue: 0.0, axis: .right, duration: 1, easingOption: .easeInBack)
        }
    }
    
    func updatePredictionGraph() {
        let dataIndex = 1
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Graph: print prediction") }

        var colors = [NSUIColor]()
        let maxBGOffset: Float = 20
        for i in 0..<predictionData.count {
            var predictionVal = Double(predictionData[i].sgv)
            if Float(predictionVal) > topBG - maxBGOffset {
                topBG = Float(predictionVal) + maxBGOffset
            }
            // Below can be turned on to prevent out of range on the graph if desired.
            // It currently just drops them out of view
            if predictionVal > 400 {
                predictionVal = 400
                colors.append(NSUIColor.systemYellow)
            } else if predictionVal < 0 {
                predictionVal = 0
                colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemPurple)
            }
            let value = ChartDataEntry(x: predictionData[i].date, y: predictionVal)
            mainChart.addEntry(value)
            smallChart.addEntry(value)
        }
        
        smallChart.circleColors.removeAll()
        smallChart.colors.removeAll()
        mainChart.colors.removeAll()
        mainChart.circleColors.removeAll()
        if colors.count > 0 {
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Graph: prediction colors") }
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        BGChart.rightAxis.axisMaximum = Double(topBG)
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
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        for i in 0..<basalData.count{
            let value = ChartDataEntry(x: Double(basalData[i].date), y: Double(basalData[i].basalRate))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if basalData[i].basalRate  > maxBasal {
                maxBasal = basalData[i].basalRate
            }
        }
        
        BGChart.leftAxis.axisMaximum = maxBasal
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateBasalScheduledGraph() {
        var dataIndex = 5
        BGChart.lineData?.dataSets[dataIndex].clear()
        for i in 0..<basalScheduleData.count{
            let value = ChartDataEntry(x: Double(basalScheduleData[i].date), y: Double(basalScheduleData[i].basalRate))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateBolusGraph() {
        var dataIndex = 3
        var yTop: Double = 370
        var yBottom: Double = 345
        BGChart.lineData?.dataSets[dataIndex].clear()

        for i in 0..<bolusData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 0
            
            // Check overlapping carbs to shift left if needed
            let bolusShift = findNextBolusTime(timeWithin: 240, needle: bolusData[i].date, haystack: bolusData, startingIndex: i)
            var dateTimeStamp = bolusData[i].date
            if bolusShift {
                // Move it half the distance between BG readings
                dateTimeStamp = dateTimeStamp - 150
            }
            
  
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(bolusData[i].sgv), data: formatter.string(from: NSNumber(value: bolusData[i].value)))
            BGChart.data?.dataSets[dataIndex].addEntry(dot)

        }
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateCarbGraph() {
        var dataIndex = 4
        BGChart.lineData?.dataSets[dataIndex].clear()

        
        for i in 0..<carbData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 1

            
            var valueString: String = formatter.string(from: NSNumber(value: carbData[i].value))!
            
            if carbData[i].absorptionTime > 0 && UserDefaultsRepository.showAbsorption.value {
                let hours = carbData[i].absorptionTime / 60
                valueString += " " + String(hours) + "h"
            }
            
            // Check overlapping carbs to shift left if needed
            let carbShift = findNextCarbTime(timeWithin: 250, needle: carbData[i].date, haystack: carbData, startingIndex: i)
            var dateTimeStamp = carbData[i].date
            if carbShift {
                dateTimeStamp = dateTimeStamp - 250
            }
            
            
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(carbData[i].sgv), data: valueString)
            BGChart.data?.dataSets[dataIndex].addEntry(dot)
            
            
            

        }
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateBGCheckGraph() {
        var dataIndex = 7
        BGChart.lineData?.dataSets[dataIndex].clear()
        for i in 0..<bgCheckData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 1
            let value = ChartDataEntry(x: Double(bgCheckData[i].date), y: Double(bgCheckData[i].sgv), data: formatter.string(from: NSNumber(value: bgCheckData[i].sgv)))
            BGChart.data?.dataSets[dataIndex].addEntry(value)

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateSuspendGraph() {
        var dataIndex = 8
        BGChart.lineData?.dataSets[dataIndex].clear()
        let thisData = suspendGraphData
        for i in 0..<thisData.count{
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: "Suspend Pump")
            BGChart.data?.dataSets[dataIndex].addEntry(value)

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateResumeGraph() {
        var dataIndex = 9
        BGChart.lineData?.dataSets[dataIndex].clear()
        let thisData = resumeGraphData
        for i in 0..<thisData.count{
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: "Resume Pump")
            BGChart.data?.dataSets[dataIndex].addEntry(value)

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateSensorStart() {
        var dataIndex = 10
        BGChart.lineData?.dataSets[dataIndex].clear()
        let thisData = sensorStartGraphData
        for i in 0..<thisData.count{
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: "Start Sensor")
            BGChart.data?.dataSets[dataIndex].addEntry(value)

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
    
    func updateNotes() {
        var dataIndex = 11
        BGChart.lineData?.dataSets[dataIndex].clear()
        let thisData = noteGraphData
        for i in 0..<thisData.count{
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: thisData[i].note)
            BGChart.data?.dataSets[dataIndex].addEntry(value)

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
 
    func createSmallBGGraph(){
        let entries = bgData
       var bgChartEntry = [ChartDataEntry]()
       var colors = [NSUIColor]()
        
        
        let lineBG = LineChartDataSet(entries:bgChartEntry, label: "")
        
        lineBG.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        lineBG.highlightEnabled = true
        lineBG.drawHorizontalHighlightIndicatorEnabled = false
        lineBG.drawVerticalHighlightIndicatorEnabled = false
        lineBG.highlightColor = NSUIColor.label
        lineBG.drawValuesEnabled = false
        lineBG.lineWidth = 2
        
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
        linePrediction.lineWidth = 2
        

        let data = LineChartData()
        data.addDataSet(lineBG)
        data.addDataSet(linePrediction)
        BGChartFull.highlightPerDragEnabled = true
        BGChartFull.leftAxis.enabled = false
        BGChartFull.rightAxis.enabled = false
        BGChartFull.xAxis.enabled = false
        BGChartFull.legend.enabled = false
        BGChartFull.scaleYEnabled = false
        BGChartFull.scaleXEnabled = false
        BGChartFull.drawGridBackgroundEnabled = false
        BGChartFull.data = data
    }
    
    
    func updateOverrideGraph() {
        var dataIndex = 6
        var yTop: Double = Double(topBG - 1)
        var yBottom: Double = Double(topBG - 25)
        var chart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        chart.clear()
        let thisData = overrideGraphData
        
        var colors = [NSUIColor]()
        for i in 0..<thisData.count{
            let thisItem = thisData[i]
            let multiplier = thisItem.insulNeedsScaleFactor as! Double * 100.0
            //let labelText = String(format: "%.0f%%", multiplier)
            var labelText = thisItem.reason + "\r\n"
            labelText += String(Int(thisItem.insulNeedsScaleFactor * 100)) + "% "
            if thisItem.correctionRange.count == 2 {
                labelText += String(thisItem.correctionRange[0]) + "-" + String(thisItem.correctionRange[1])
            }
            
            
            // Start Dot
            // Shift dots 30 seconds to create an empty 0 space between consecutive temps
            let preStartDot = ChartDataEntry(x: Double(thisItem.date), y: yBottom, data: "hide")
            BGChart.data?.dataSets[dataIndex].addEntry(preStartDot)
            let value = ChartDataEntry(x: Double(thisItem.date + 1), y: yTop, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            
            if Double(thisItem.insulNeedsScaleFactor) == 1.0 {
                colors.append(NSUIColor.systemGray.withAlphaComponent(0.0))
            } else if i >= overrideGraphData.count - 2 {
                colors.append(NSUIColor.systemGreen)
            } else {
                colors.append(NSUIColor.systemGray.withAlphaComponent(CGFloat(thisItem.insulNeedsScaleFactor / 2)))
            }
            
            // End Dot
            let endDot = ChartDataEntry(x: Double(thisItem.endDate - 1), y: yTop, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(endDot)
            // Post end dot
            let postEndDot = ChartDataEntry(x: Double(thisItem.endDate), y: yBottom, data: "hide")
            BGChart.data?.dataSets[dataIndex].addEntry(postEndDot)
            
            if Double(thisItem.insulNeedsScaleFactor) == 1.0 {
                colors.append(NSUIColor.systemGray.withAlphaComponent(0.0))
            } else if i >= overrideGraphData.count - 2 {
                colors.append(NSUIColor.systemGreen)
            } else {
                colors.append(NSUIColor.systemGray.withAlphaComponent(CGFloat(thisItem.insulNeedsScaleFactor / 2)))
            }
        }
        
        // Set Colors
        let line = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        line.colors.removeAll()
        line.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                chart.addColor(colors[i])
                chart.circleColors.append(colors[i])
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
    }
  
}
