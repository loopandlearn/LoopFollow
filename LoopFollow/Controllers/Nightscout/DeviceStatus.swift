// LoopFollow
// DeviceStatus.swift
// Created by Jonas Björkert on 2023-10-05.

import Charts
import Foundation
import UIKit

extension MainViewController {
    func webLoadNSDeviceStatus() {
        let parameters = ["count": "1"]
        NightscoutUtils.executeDynamicRequest(eventType: .deviceStatus, parameters: parameters) { result in
            switch result {
            case let .success(json):
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
        LogManager.shared.log(category: .deviceStatus, message: "Device status fetch failed!", limitIdentifier: "Device status fetch failed!")
        DispatchQueue.main.async {
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date().addingTimeInterval(10))
            self.evaluateNotLooping()
        }
    }

    func evaluateNotLooping() {
        guard let statusStackView = LoopStatusLabel.superview as? UIStackView else { return }

        let now = TimeInterval(Date().timeIntervalSince1970)
        let lastLoopTime = UserDefaultsRepository.alertLastLoopTime.value
        let isAlarmEnabled = UserDefaultsRepository.alertNotLoopingActive.value
        let nonLoopingTimeThreshold: TimeInterval

        if isAlarmEnabled {
            nonLoopingTimeThreshold = Double(UserDefaultsRepository.alertNotLooping.value * 60)
        } else {
            nonLoopingTimeThreshold = 15 * 60
        }

        if IsNightscoutEnabled(), (now - lastLoopTime) >= nonLoopingTimeThreshold, lastLoopTime > 0 {
            IsNotLooping = true
            statusStackView.distribution = .fill

            PredictionLabel.isHidden = true
            LoopStatusLabel.frame = CGRect(x: 0, y: 0, width: statusStackView.frame.width, height: statusStackView.frame.height)

            LoopStatusLabel.textAlignment = .center
            LoopStatusLabel.text = "⚠️ Not Looping!"
            LoopStatusLabel.textColor = UIColor.systemYellow
            LoopStatusLabel.font = UIFont.boldSystemFont(ofSize: 18)

        } else {
            IsNotLooping = false
            statusStackView.distribution = .fillEqually
            PredictionLabel.isHidden = false

            LoopStatusLabel.textAlignment = .right
            LoopStatusLabel.font = UIFont.systemFont(ofSize: 17)

            if UserDefaultsRepository.forceDarkMode.value {
                LoopStatusLabel.textColor = UIColor.white
            } else {
                LoopStatusLabel.textColor = UIColor.black
            }
        }
    }

    // NS Device Status Response Processor
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String: AnyObject]]) {
        infoManager.clearInfoData(types: [.iob, .cob, .override, .battery, .pump, .target, .isf, .carbRatio, .updated, .recBolus, .tdd])

        if jsonDeviceStatus.count == 0 {
            LogManager.shared.log(category: .deviceStatus, message: "Device status is empty")
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date().addingTimeInterval(5 * 60))
            return
        }

        // Process the current data first
        let lastDeviceStatus = jsonDeviceStatus[0] as [String: AnyObject]?

        // pump and uploader
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        if let lastPumpRecord = lastDeviceStatus?["pump"] as! [String: AnyObject]? {
            if let lastPumpTime = formatter.date(from: (lastPumpRecord["clock"] as! String))?.timeIntervalSince1970 {
                if let reservoirData = lastPumpRecord["reservoir"] as? Double {
                    latestPumpVolume = reservoirData
                    infoManager.updateInfoData(type: .pump, value: String(format: "%.0f", reservoirData) + "U")
                } else {
                    latestPumpVolume = 50.0
                    infoManager.updateInfoData(type: .pump, value: "50+U")
                }

                if let uploader = lastDeviceStatus?["uploader"] as? [String: AnyObject],
                   let upbat = uploader["battery"] as? Double
                {
                    let batteryText: String
                    if let isCharging = uploader["isCharging"] as? Bool, isCharging {
                        batteryText = "⚡️ " + String(format: "%.0f", upbat) + "%"
                    } else {
                        batteryText = String(format: "%.0f", upbat) + "%"
                    }
                    infoManager.updateInfoData(type: .battery, value: batteryText)
                    UserDefaultsRepository.deviceBatteryLevel.value = upbat

                    let timestamp = uploader["timestamp"] as? Date ?? Date()
                    let currentBattery = DataStructs.batteryStruct(batteryLevel: upbat, timestamp: timestamp)
                    deviceBatteryData.append(currentBattery)

                    // store only the last 30 battery readings
                    if deviceBatteryData.count > 30 {
                        deviceBatteryData.removeFirst()
                    }
                }
            }
        }

        // Loop - handle new data
        if let lastLoopRecord = lastDeviceStatus?["loop"] as! [String: AnyObject]? {
            DeviceStatusLoop(formatter: formatter, lastLoopRecord: lastLoopRecord)

            var oText = ""
            currentOverride = 1.0
            if let lastOverride = lastDeviceStatus?["override"] as? [String: AnyObject],
               let isActive = lastOverride["active"] as? Bool, isActive
            {
                if let lastCorrection = lastOverride["currentCorrectionRange"] as? [String: AnyObject],
                   let minValue = lastCorrection["minValue"] as? Double,
                   let maxValue = lastCorrection["maxValue"] as? Double
                {
                    if let multiplier = lastOverride["multiplier"] as? Double {
                        currentOverride = multiplier
                        oText += String(format: "%.0f%%", multiplier * 100)
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
        if let lastLoopRecord = lastDeviceStatus?["openaps"] as! [String: AnyObject]? {
            DeviceStatusOpenAPS(formatter: formatter, lastDeviceStatus: lastDeviceStatus, lastLoopRecord: lastLoopRecord)
        }

        // Start the timer based on the timestamp
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        let secondsAgo = now - UserDefaultsRepository.alertLastLoopTime.value

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

        evaluateNotLooping()
        LogManager.shared.log(category: .deviceStatus, message: "Update Device Status done", isDebug: true)
    }
}
