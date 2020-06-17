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


extension MainViewController {
    
    // rewrite this func
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        print("chartTranslated")
        
        if  chartView == BGChart {
            let currentMatrix = chartView.viewPortHandler.touchMatrix
            BasalChart.viewPortHandler.refresh(newMatrix: currentMatrix, chart: BasalChart, invalidate: true)
        }else {
            let currentMatrix = BasalChart.viewPortHandler.touchMatrix
            BGChart.viewPortHandler.refresh(newMatrix: currentMatrix, chart: BGChart, invalidate: true)
        }
    }
    
    func createGraph(entries: [sgvData]){
        var bgChartEntry = [ChartDataEntry]()
        var colors = [NSUIColor]()
        var maxBG: Int = 250
        for i in 0..<entries.count{
            var dateString = String(entries[i].date).prefix(10)
            let dateSecondsOnly = Double(String(dateString))!
            if entries[i].sgv > maxBG {
                maxBG = entries[i].sgv
            }
            let value = ChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].sgv))
            bgChartEntry.append(value)
            
            if Double(entries[i].sgv) >= Double(UserDefaultsRepository.highLine.value) {
                colors.append(NSUIColor.systemYellow)
            } else if Double(entries[i].sgv) <= Double(UserDefaultsRepository.lowLine.value) {
                colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        // Add Prediction Data
        if predictionData.count > 0 {
            var startingTime = bgChartEntry[bgChartEntry.count - 1].x + 300
            var i = 0
            // Add 1 hour of predictions
            while i < 12 {
                var predictionVal = Double(predictionData[i])
                // Below can be turned on to prevent out of range on the graph if desired.
                // It currently just drops them out of view
                if predictionVal > 400 {
               //     predictionVal = 400
                } else if predictionVal < 0 {
                //    predictionVal = 0
                }
                let value = ChartDataEntry(x: startingTime + 5, y: predictionVal)
                bgChartEntry.append(value)
                colors.append(NSUIColor.systemPurple)
                startingTime += 300
                i += 1
            }
        }
        
        let line1 = LineChartDataSet(entries:bgChartEntry, label: "")
        line1.circleRadius = 3
        line1.circleColors = [NSUIColor.systemGreen]
        line1.drawCircleHoleEnabled = false
        if UserDefaultsRepository.showLines.value {
            line1.lineWidth = 2
        } else {
            line1.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            line1.drawCirclesEnabled = true
        } else {
            line1.drawCirclesEnabled = false
        }
        line1.setDrawHighlightIndicators(false)
        line1.valueFont.withSize(50)
        
        for i in 1..<colors.count{
            line1.addColor(colors[i])
            line1.circleColors.append(colors[i])
        }
        
        let data = LineChartData()
        data.addDataSet(line1)
        data.setValueFont(UIFont(name: UIFont.systemFont(ofSize: 10).fontName, size: 10)!)
        data.setDrawValues(false)
        
        // Clear limit lines so they don't add multiples when changing the settings
        BGChart.rightAxis.removeAllLimitLines()
        
        //Add lower red line based on low alert value
        let ll = ChartLimitLine()
        ll.limit = Double(UserDefaultsRepository.lowLine.value)
        ll.lineColor = NSUIColor.systemRed
        BGChart.rightAxis.addLimitLine(ll)
        
        //Add upper yellow line based on low alert value
        let ul = ChartLimitLine()
        ul.limit = Double(UserDefaultsRepository.highLine.value)
        ul.lineColor = NSUIColor.systemYellow
        BGChart.rightAxis.addLimitLine(ul)
        
        BGChart.xAxis.valueFormatter = ChartXValueFormatter()
        BGChart.xAxis.granularity = 1800
        BGChart.xAxis.labelTextColor = NSUIColor.label
        BGChart.xAxis.labelPosition = XAxis.LabelPosition.bottom
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 40
        BGChart.leftAxis.axisMinimum = 40
        BGChart.rightAxis.axisMaximum = Double(maxBG)
        BGChart.leftAxis.axisMaximum = Double(maxBG)
        BGChart.leftAxis.enabled = false
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.data = data
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        BGChart.setVisibleXRangeMinimum(10)
        BGChart.drawGridBackgroundEnabled = true
        BGChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        if firstGraphLoad {
            BGChart.zoom(scaleX: 18, scaleY: 1, x: 1, y: 1)
            firstGraphLoad = false
        }
        // 7000 only shows 30 minutes of the hour predictions, leaving the rest on the right of the screen requiring a scroll
        BGChart.moveViewToX(Date().timeIntervalSince1970)

        
        createSmallBGGraph(bgChartEntry: bgChartEntry, colors: colors)
      
    }
    
    func createSmallBGGraph(bgChartEntry: [ChartDataEntry], colors: [NSUIColor]){
        //24 Hour Small Graph
        let line2 = LineChartDataSet(entries:bgChartEntry, label: "Number")
        line2.drawCirclesEnabled = false
        line2.setDrawHighlightIndicators(false)
        line2.lineWidth = 1
        for i in 1..<colors.count{
            line2.addColor(colors[i])
            line2.circleColors.append(colors[i])
        }
        
        let data2 = LineChartData()
        data2.addDataSet(line2)
        BGChartFull.leftAxis.enabled = false
        BGChartFull.rightAxis.enabled = false
        BGChartFull.xAxis.enabled = false
        BGChartFull.legend.enabled = false
        BGChartFull.scaleYEnabled = false
        BGChartFull.scaleXEnabled = false
        BGChartFull.drawGridBackgroundEnabled = false
        BGChartFull.data = data2
    }
    
    func createBasalGraph(entries: [basalGraphStruct]){
        var chartEntry = [ChartDataEntry]()
        for i in 0..<entries.count{
            let value = ChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].basalRate))
            chartEntry.append(value)
        }
        let line1 = LineChartDataSet(entries:chartEntry, label: "")
        line1.circleRadius = 3
        line1.circleColors = [NSUIColor.systemBlue]
        line1.drawCircleHoleEnabled = false
        line1.setDrawHighlightIndicators(false)
        line1.setColor(NSUIColor.systemBlue, alpha: 1.0)
        line1.lineWidth = 3
        line1.drawFilledEnabled = true
        line1.fillColor = NSUIColor.systemBlue
        line1.drawCirclesEnabled = false
        let data = LineChartData()
        data.addDataSet(line1)
        data.setValueFont(UIFont(name: UIFont.systemFont(ofSize: 10).fontName, size: 10)!)
        data.setDrawValues(false)
        
        BasalChart.xAxis.valueFormatter = ChartXValueFormatter()
        BasalChart.xAxis.granularity = 1800
        BasalChart.xAxis.labelTextColor = NSUIColor.label
        BasalChart.xAxis.labelPosition = XAxis.LabelPosition.bottom
        BasalChart.rightAxis.labelTextColor = NSUIColor.label
        BasalChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BasalChart.leftAxis.enabled = false
        BasalChart.legend.enabled = false
        BasalChart.scaleYEnabled = false
        BasalChart.data = data
        BasalChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        BasalChart.setVisibleXRangeMinimum(10)
        BasalChart.drawGridBackgroundEnabled = true
        BasalChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        if firstBasalGraphLoad {
            BasalChart.zoom(scaleX: 18, scaleY: 1, x: 1, y: 1)
            firstBasalGraphLoad = false
        }
        // 7000 only shows 30 minutes of the hour predictions, leaving the rest on the right of the screen requiring a scroll
        BasalChart.moveViewToX(Date().timeIntervalSince1970)
        
        // Bar Chart Build
        /*var chartEntry = [BarChartDataEntry]()
        for i in 0..<entries.count{
            let value = BarChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].basalRate))
            chartEntry.append(value)
        }
        let bar1 = BarChartDataSet(entries:chartEntry, label: "")
        bar1.setColor(NSUIColor.systemBlue, alpha: 0.5)
        let data = BarChartData()
        data.addDataSet(bar1)
        data.setValueFont(UIFont(name: UIFont.systemFont(ofSize: 10).fontName, size: 10)!)
        data
        data.barWidth = 290
        BasalChart.xAxis.valueFormatter = ChartXValueFormatter()
        BasalChart.xAxis.granularity = 1800
        BasalChart.data = data
        BasalChart.legend.enabled = false
        BasalChart.xAxis.drawGridLinesEnabled = false
        BasalChart.leftAxis.drawGridLinesEnabled = false
        BasalChart.rightAxis.drawGridLinesEnabled = false
        BasalChart.leftAxis.enabled = false
        BasalChart.scaleYEnabled = false
        if firstBasalGraphLoad {
            BasalChart.zoom(scaleX: 18, scaleY: 1, x: 1, y: 1)
            firstBasalGraphLoad = false
        }
        BasalChart.moveViewToX(BGChart.chartXMax)
        */
    }
}
