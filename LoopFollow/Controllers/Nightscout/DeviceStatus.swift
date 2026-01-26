// LoopFollow
// DeviceStatus.swift

import Charts
import Foundation
import HealthKit
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
                        Storage.shared.lastLoopingChecked.value = Date()
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
            Storage.shared.lastLoopingChecked.value = Date()
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date().addingTimeInterval(10))
            self.evaluateNotLooping()
        }
    }

    func evaluateNotLooping() {
        guard let statusStackView = LoopStatusLabel.superview as? UIStackView else { return }
        guard let lastLoopTime = Observable.shared.alertLastLoopTime.value, lastLoopTime > 0 else {
            return
        }

        let now = TimeInterval(Date().timeIntervalSince1970)
        let nonLoopingTimeThreshold: TimeInterval = 15 * 60

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

            switch Storage.shared.appearanceMode.value {
            case .dark:
                LoopStatusLabel.textColor = UIColor.white
            case .light:
                LoopStatusLabel.textColor = UIColor.black
            case .system:
                LoopStatusLabel.textColor = UIColor.label
            }
        }
    }

    // NS Device Status Response Processor
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String: AnyObject]]) {
        infoManager.clearInfoData(types: [.iob, .cob, .battery, .pump, .pumpBattery, .target, .isf, .carbRatio, .updated, .recBolus, .tdd])

        // For Loop, clear the current override here - For Trio, it is handled using treatments
        if Storage.shared.device.value == "Loop" {
            infoManager.clearInfoData(types: [.override])
        }

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

        Observable.shared.previousAlertLastLoopTime.value = Observable.shared.alertLastLoopTime.value

        if let lastPumpRecord = lastDeviceStatus?["pump"] as! [String: AnyObject]? {
            if let bolusIncrement = lastPumpRecord["bolusIncrement"] as? Double, bolusIncrement > 0 {
                Storage.shared.bolusIncrement.value = HKQuantity(unit: .internationalUnit(), doubleValue: bolusIncrement)
                Storage.shared.bolusIncrementDetected.value = true
            } else if let model = lastPumpRecord["model"] as? String, model == "Dash" {
                Storage.shared.bolusIncrement.value = HKQuantity(unit: .internationalUnit(), doubleValue: 0.05)
                Storage.shared.bolusIncrementDetected.value = true
            } else {
                Storage.shared.bolusIncrementDetected.value = false
            }

            if let clockString = lastPumpRecord["clock"] as? String,
               let lastPumpTime = formatter.date(from: clockString)?.timeIntervalSince1970
            {
                let storedTime = Observable.shared.alertLastLoopTime.value ?? 0
                if lastPumpTime > storedTime {
                    Observable.shared.alertLastLoopTime.value = lastPumpTime
                }

                if let reservoirData = lastPumpRecord["reservoir"] as? Double {
                    latestPumpVolume = reservoirData
                    infoManager.updateInfoData(type: .pump, value: String(format: "%.0f", reservoirData) + "U")
                } else {
                    latestPumpVolume = 50.0
                    infoManager.updateInfoData(type: .pump, value: "50+U")
                }
            }

            // Parse pump battery percentage
            if let pumpBatteryRecord = lastPumpRecord["battery"] as? [String: AnyObject],
               let pumpBatteryPercent = pumpBatteryRecord["percent"] as? Double
            {
                infoManager.updateInfoData(type: .pumpBattery, value: String(format: "%.0f", pumpBatteryPercent) + "%")
                Observable.shared.pumpBatteryLevel.value = pumpBatteryPercent
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
                Observable.shared.deviceBatteryLevel.value = upbat

                let timestamp = uploader["timestamp"] as? Date ?? Date()
                let currentBattery = DataStructs.batteryStruct(batteryLevel: upbat, timestamp: timestamp)
                deviceBatteryData.append(currentBattery)

                // store only the last 30 battery readings
                if deviceBatteryData.count > 30 {
                    deviceBatteryData.removeFirst()
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
        let secondsAgo = now - (Observable.shared.alertLastLoopTime.value ?? 0)

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
                TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(3))
            }
        }

        evaluateNotLooping()

        // Mark device status as loaded for initial loading state
        markDataLoaded("deviceStatus")

        if Storage.shared.contactEnabled.value, Storage.shared.contactIOB.value != .off {
            contactImageUpdater.updateContactImage(
                bgValue: Observable.shared.bgText.value,
                trend: Observable.shared.directionText.value,
                delta: Observable.shared.deltaText.value,
                iob: Observable.shared.iobText.value,
                stale: Observable.shared.bgStale.value
            )
        }

        LogManager.shared.log(category: .deviceStatus, message: "Update Device Status done", isDebug: true)
    }
}
