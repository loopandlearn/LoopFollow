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
    

    

    
    func createGraph(){
        self.BGChart.clear()
        
        // Create the BG Graph Data
        let entries = bgData
        var bgChartEntry = [ChartDataEntry]()
        var colors = [NSUIColor]()
        var maxBG: Int = 250
        if bgData.count > 0 {
            for i in 0..<entries.count{
                var dateString = String(entries[i].date).prefix(10)
                let dateSecondsOnly = Double(String(dateString))!
                if entries[i].sgv > maxBG - 40 {
                    maxBG = entries[i].sgv + 40
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
        }
        
        // Add Prediction Data
        if predictionData.count > 0 && bgData.count > 0 {
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
        
        // Setup BG line details
        let lineBG = LineChartDataSet(entries:bgChartEntry, label: "")
        lineBG.circleRadius = 3
        lineBG.circleColors = [NSUIColor.systemGreen]
        lineBG.drawCircleHoleEnabled = false
        lineBG.axisDependency = YAxis.AxisDependency.right
        lineBG.highlightEnabled = false
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
        
        for i in 1..<colors.count{
            lineBG.addColor(colors[i])
            lineBG.circleColors.append(colors[i])
        }
        

        // create Basal graph data
        var chartEntry = [ChartDataEntry]()
        var maxBasal = 1.0
        if basalData.count > 0 {
            for i in 0..<basalData.count{
                let value = ChartDataEntry(x: Double(basalData[i].date), y: Double(basalData[i].basalRate))
                chartEntry.append(value)
                if basalData[i].basalRate  > maxBasal {
                    maxBasal = basalData[i].basalRate
                }
            }
        }
        // Setup Basal line details
        let lineBasal = LineChartDataSet(entries:chartEntry, label: "")
        lineBasal.setDrawHighlightIndicators(false)
        lineBasal.setColor(NSUIColor.systemBlue, alpha: 0.5)
        lineBasal.lineWidth = 0
        lineBasal.drawFilledEnabled = true
        lineBasal.fillColor = NSUIColor.systemBlue.withAlphaComponent(0.8)
        lineBasal.drawCirclesEnabled = false
        lineBasal.axisDependency = YAxis.AxisDependency.left
        lineBasal.highlightEnabled = false
        lineBasal.drawValuesEnabled = false
        
        // Boluses
        var chartEntryBolus = [ChartDataEntry]()
        if bolusData.count > 0 {
            for i in 0..<bolusData.count{
                let value = ChartDataEntry(x: Double(bolusData[i].date), y: Double(bolusData[i].sgv + 10), data: String(bolusData[i].value))
                chartEntryBolus.append(value)
            }
        }
        let lineBolus = LineChartDataSet(entries:chartEntryBolus, label: "")
        lineBolus.circleRadius = 7
        lineBolus.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineBolus.drawCircleHoleEnabled = false
        lineBolus.setDrawHighlightIndicators(false)
        lineBolus.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineBolus.drawCirclesEnabled = true
        lineBolus.lineWidth = 0
        lineBolus.axisDependency = YAxis.AxisDependency.right
        lineBolus.valueFormatter = ChartYDataValueFormatter()
        lineBolus.drawValuesEnabled = true
        lineBolus.valueTextColor = NSUIColor.label

        
        // Carbs
        var chartEntryCarbs = [ChartDataEntry]()
        if carbData.count > 0 {
            for i in 0..<carbData.count{
                let value = ChartDataEntry(x: Double(carbData[i].date), y: Double(carbData[i].sgv + 30), data: String(carbData[i].value))
                chartEntryCarbs.append(value)
            }
        }
        let lineCarbs = LineChartDataSet(entries:chartEntryCarbs, label: "")
        lineCarbs.circleRadius = 7
        lineCarbs.circleColors = [NSUIColor.systemOrange.withAlphaComponent(0.75)]
        lineCarbs.drawCircleHoleEnabled = false
        lineCarbs.setDrawHighlightIndicators(false)
        lineCarbs.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineCarbs.drawCirclesEnabled = true
        lineCarbs.lineWidth = 0
        lineCarbs.axisDependency = YAxis.AxisDependency.right
        lineCarbs.valueFormatter = ChartYDataValueFormatter()
        lineCarbs.drawValuesEnabled = true
        lineCarbs.valueTextColor = NSUIColor.label
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.addDataSet(lineBG)
        data.addDataSet(lineBasal)
        data.addDataSet(lineBolus)
        data.addDataSet(lineCarbs)
        data.setValueFont(UIFont.systemFont(ofSize: 12))
        
        
        // Add marker popups for bolus and carbs
        // Changed to display values
        //let marker = PillMarker(color: .secondarySystemBackground, font: UIFont.boldSystemFont(ofSize: 14), textColor: .label)
        //BGChart.marker = marker
        
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
        
        // Setup the main graph overall details
        BGChart.xAxis.valueFormatter = ChartXValueFormatter()
        BGChart.xAxis.granularity = 1800
        BGChart.xAxis.labelTextColor = NSUIColor.label
        BGChart.xAxis.labelPosition = XAxis.LabelPosition.bottom
        
        BGChart.leftAxis.enabled = true
        BGChart.leftAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.leftAxis.axisMaximum = maxBasal
        BGChart.leftAxis.axisMinimum = 0.0
        BGChart.leftAxis.drawGridLinesEnabled = false
        
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 40
        BGChart.rightAxis.axisMaximum = Double(maxBG)
        
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.drawGridBackgroundEnabled = true
        BGChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        
        BGChart.data = data
        
        // This must be called after the data is loaded
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        BGChart.setVisibleXRangeMinimum(10)
        if firstGraphLoad {
            BGChart.zoom(scaleX: 18, scaleY: 1, x: 1, y: 1)
            firstGraphLoad = false
        }
        if minAgoBG < 1 {
            BGChart.moveViewToAnimated(xValue: dateTimeUtils.getNowTimeIntervalUTC() - (BGChart.visibleXRange * 0.7), yValue: 0.0, axis: .right, duration: 1, easingOption: .easeInBack)
        }
        
        
        if bgData.count > 0 {
            createSmallBGGraph(bgChartEntry: bgChartEntry, colors: colors)
        }
        
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
    
 
}
