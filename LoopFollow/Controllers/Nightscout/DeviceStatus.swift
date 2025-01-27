//
//  DeviceStatus.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import Charts

extension MainViewController {
    // NS Device Status Web Call
    func webLoadNSDeviceStatus() {
        let count = ObservableUserDefaults.shared.device.value == "Trio" && Observable.shared.isLastDeviceStatusSuggested.value ? "5" : "1"
        if count != "1" {
            LogManager.shared.log(category: .deviceStatus, message: "Fetching \(count) device status records")
        }

        let parameters: [String: String] = ["count": count]
        NightscoutUtils.executeDynamicRequest(eventType: .deviceStatus, parameters: parameters) { result in
            switch result {
            case .success(let json):
                if let jsonDeviceStatus = json as? [[String: AnyObject]] {
                    DispatchQueue.main.async {
                        self.updateDeviceStatusDisplay(jsonDeviceStatus: jsonDeviceStatus)
                    }
                } else {
                    self.handleDeviceStatusError()
                }
            case .failure:
                self.handleDeviceStatusError()
            }
        }
    }

    private func handleDeviceStatusError() {
        LogManager.shared.log(category: .deviceStatus, message: "Device status fetch failed!")
        DispatchQueue.main.async {
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date().addingTimeInterval(10))
        }
    }
    
    func evaluateNotLooping(lastLoopTime: TimeInterval) {
        if let statusStackView = LoopStatusLabel.superview as? UIStackView {
            if ((TimeInterval(Date().timeIntervalSince1970) - lastLoopTime) / 60) > 15 {
                IsNotLooping = true
                // Change the distribution to 'fill' to allow manual resizing of arranged subviews
                statusStackView.distribution = .fill
                
                // Hide PredictionLabel and expand LoopStatusLabel to fill the entire stack view
                PredictionLabel.isHidden = true
                LoopStatusLabel.frame = CGRect(x: 0, y: 0, width: statusStackView.frame.width, height: statusStackView.frame.height)
                
                // Update LoopStatusLabel's properties to display Not Looping
                LoopStatusLabel.textAlignment = .center
                LoopStatusLabel.text = "⚠️ Not Looping!"
                LoopStatusLabel.textColor = UIColor.systemYellow
                LoopStatusLabel.font = UIFont.boldSystemFont(ofSize: 18)
                
            } else {
                IsNotLooping = false
                // Restore the original distribution and visibility of labels
                statusStackView.distribution = .fillEqually
                PredictionLabel.isHidden = false
                
                // Reset LoopStatusLabel's properties
                LoopStatusLabel.textAlignment = .right
                LoopStatusLabel.font = UIFont.systemFont(ofSize: 17)

                if UserDefaultsRepository.forceDarkMode.value {
                    LoopStatusLabel.textColor = UIColor.white
                } else {
                    LoopStatusLabel.textColor = UIColor.black
                }
            }
        }
        latestLoopTime = lastLoopTime
    }
        
    // NS Device Status Response Processor
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String:AnyObject]]) {
        infoManager.clearInfoData(types: [.iob, .cob, .override, .battery, .pump, .target, .isf, .carbRatio, .updated, .recBolus, .tdd])

        if jsonDeviceStatus.count == 0 {
            LogManager.shared.log(category: .deviceStatus, message: "Device status is empty")
            return
        }
        
        //Process the current data first
        let lastDeviceStatus = jsonDeviceStatus[0] as [String : AnyObject]?
        
        //pump and uploader
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        if let lastPumpRecord = lastDeviceStatus?["pump"] as! [String : AnyObject]? {
            if let lastPumpTime = formatter.date(from: (lastPumpRecord["clock"] as! String))?.timeIntervalSince1970  {
                if let reservoirData = lastPumpRecord["reservoir"] as? Double {
                    latestPumpVolume = reservoirData
                    infoManager.updateInfoData(type: .pump, value: String(format: "%.0f", reservoirData) + "U")
                } else {
                    latestPumpVolume = 50.0
                    infoManager.updateInfoData(type: .pump, value: "50+U")
                }

                if let uploader = lastDeviceStatus?["uploader"] as? [String: AnyObject],
                   let upbat = uploader["battery"] as? Double {
                    infoManager.updateInfoData(type: .battery, value: String(format: "%.0f", upbat) + "%")
                    UserDefaultsRepository.deviceBatteryLevel.value = upbat
                }
            }
        }
        
        // Loop - handle new data
        if let lastLoopRecord = lastDeviceStatus?["loop"] as! [String : AnyObject]? {
            DeviceStatusLoop(formatter: formatter, lastLoopRecord: lastLoopRecord)

            var oText = ""
            currentOverride = 1.0
            if let lastOverride = lastDeviceStatus?["override"] as? [String: AnyObject],
               let isActive = lastOverride["active"] as? Bool, isActive {
                if let lastCorrection = lastOverride["currentCorrectionRange"] as? [String: AnyObject],
                   let minValue = lastCorrection["minValue"] as? Double,
                   let maxValue = lastCorrection["maxValue"] as? Double {

                    if let multiplier = lastOverride["multiplier"] as? Double {
                        currentOverride = multiplier
                        oText += String(format: "%.0f%%", (multiplier * 100))
                    } else {
                        oText += "100%"
                    }

                    oText += " ("
                    oText += Localizer.toDisplayUnits(String(minValue)) + "-" + Localizer.toDisplayUnits(String(maxValue)) + ")"
                }

                infoManager.updateInfoData(type: .override, value: oText)
            } else {
                infoManager.clearInfoData(type: .override)
            }
        }

        // OpenAPS - handle new data
        if let lastLoopRecord = lastDeviceStatus?["openaps"] as! [String : AnyObject]? {
            DeviceStatusOpenAPS(formatter: formatter, lastDeviceStatus: lastDeviceStatus, lastLoopRecord: lastLoopRecord, jsonDeviceStatus: jsonDeviceStatus)
        }

        // Start the timer based on the timestamp
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        let secondsAgo = now - latestLoopTime
        
        DispatchQueue.main.async {
            if secondsAgo >= (20 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .deviceStatus,
                    to: Date().addingTimeInterval(5 * 60)
                )

            } else if secondsAgo >= (10 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .deviceStatus,
                    to: Date().addingTimeInterval(60)
                )

            } else if secondsAgo >= (7 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .deviceStatus,
                    to: Date().addingTimeInterval(30)
                )

            } else if secondsAgo >= (5 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .deviceStatus,
                    to: Date().addingTimeInterval(10)
                )
            } else {
                let interval = (310 - secondsAgo)
                TaskScheduler.shared.rescheduleTask(
                    id: .deviceStatus,
                    to: Date().addingTimeInterval(interval)
                )
            }
        }
        LogManager.shared.log(category: .deviceStatus, message: "Update Device Status done", isDebug: true)
    }
}
