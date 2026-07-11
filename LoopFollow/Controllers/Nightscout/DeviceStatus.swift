// LoopFollow
// DeviceStatus.swift

import Foundation
import HealthKit
import SwiftUI

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
        guard let lastLoopTime = Observable.shared.alertLastLoopTime.value, lastLoopTime > 0 else {
            return
        }

        let now = TimeInterval(Date().timeIntervalSince1970)
        let nonLoopingTimeThreshold: TimeInterval = 15 * 60

        if IsNightscoutEnabled(), (now - lastLoopTime) >= nonLoopingTimeThreshold, lastLoopTime > 0 {
            IsNotLooping = true
            Observable.shared.isNotLooping.value = true

            Observable.shared.loopStatusText.value = "⚠️ Not Looping!"
            Observable.shared.loopStatusColor.value = .yellow
            #if !targetEnvironment(macCatalyst)
                LiveActivityManager.shared.refreshFromCurrentState(reason: "notLooping")
            #endif

        } else {
            IsNotLooping = false
            Observable.shared.isNotLooping.value = false

            Observable.shared.loopStatusColor.value = .primary
            #if !targetEnvironment(macCatalyst)
                LiveActivityManager.shared.refreshFromCurrentState(reason: "loopingResumed")
            #endif
        }
    }

    // NS Device Status Response Processor
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String: AnyObject]]) {
        let previousIOBText = Observable.shared.iobText.value
        // Capture the enactedOrSuggested timestamp BEFORE we process the new record,
        // so we can detect if the new record was "sparse" (no parseable timestamp /
        // bg / TDD inside enactedOrSuggested). Trio occasionally writes a thin
        // devicestatus record (e.g. SMB-only notifications) that doesn't have those
        // fields; landing on one of those records leaves Updated / TDD / Smoothed BG
        // blank — we want to keep polling until a full record arrives.
        let previousEnactedTime = Observable.shared.enactedOrSuggested.value
        infoManager.clearInfoData(types: [.iob, .cob, .battery, .pump, .pumpBattery, .target, .isf, .carbRatio, .updated, .recBolus, .tdd, .smoothedBg])

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
                    Storage.shared.lastLoopTime.value = lastPumpTime
                }

                if let reservoirData = lastPumpRecord["reservoir"] as? Double {
                    latestPumpVolume = reservoirData
                    infoManager.updateInfoData(type: .pump, value: String(format: "%.0f", reservoirData) + "U")
                    Storage.shared.lastPumpReservoirU.value = reservoirData
                } else {
                    latestPumpVolume = 50.0
                    infoManager.updateInfoData(type: .pump, value: "50+U")
                    Storage.shared.lastPumpReservoirU.value = nil
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

        // Two reasons we may want to poll devicestatus aggressively (instead of the
        // normal ~5-minute cadence):
        //   1) Smoothed-BG feature is on and the latest CGM dot has no matching
        //      smoothed point yet (Trio's loop runs shortly after each new BG).
        //   2) The latest devicestatus record we just processed was "sparse" — i.e.
        //      its enactedOrSuggested block had no parseable timestamp, so Updated
        //      / TDD / Smoothed BG didn't repopulate. Trio occasionally writes
        //      thin records (SMB-only notifications, partial loop runs); landing on
        //      one shouldn't leave the info table blank for 5 minutes.
        // Either reason: backoff cadence 3s for the first 60s after the BG, then
        // 15s out to 5 minutes, then give up.
        // When bgData is still empty (cold app launch — BG fetch may not have
        // completed yet by the time the first devicestatus parse runs), treat age
        // as 0 instead of infinity so we still allow fast-poll. Otherwise the very
        // first cold-launch parse would silently skip retry and leave the rows
        // blank for the full 5-minute normal cadence.
        let latestBgAge: TimeInterval = bgData.last.map { Date().timeIntervalSince1970 - $0.date } ?? 0
        let recordIsSparse = (Observable.shared.enactedOrSuggested.value == previousEnactedTime)
        let needsSmoothedBgRetry: Bool = {
            guard Storage.shared.displaySmoothedBG.value,
                  !smoothedBgData.isEmpty,
                  let latestBg = bgData.last,
                  latestBgAge < 300
            else { return false }
            return smoothedBg(near: latestBg.date) == nil
        }()
        let needsSparseRecordRetry: Bool = recordIsSparse && latestBgAge < 300
        let needsRetry = needsSmoothedBgRetry || needsSparseRecordRetry
        let retryDelay: TimeInterval = latestBgAge < 60 ? 3 : 15

        DispatchQueue.main.async {
            if needsRetry {
                TaskScheduler.shared.rescheduleTask(
                    id: .deviceStatus,
                    to: Date().addingTimeInterval(retryDelay)
                )
                return
            }

            var interval: Double
            if secondsAgo >= (20 * 60) {
                interval = 5 * 60
            } else if secondsAgo >= (10 * 60) {
                interval = 60
            } else if secondsAgo >= (7 * 60) {
                interval = 30
            } else if secondsAgo >= (5 * 60) {
                interval = 10
            } else {
                interval = 310 - secondsAgo
                TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(3))
            }

            if NightscoutSocketManager.shared.connectionState == .authenticated {
                interval = max(interval * 3, 60)
            }

            TaskScheduler.shared.rescheduleTask(
                id: .deviceStatus,
                to: Date().addingTimeInterval(interval)
            )
        }

        evaluateNotLooping()

        // Mark device status as loaded for initial loading state
        markDataLoaded("deviceStatus")

        // First successful loop run of the session: backfill the smoothed-BG history
        // so the popup can show ✨ values for older glucose dots, not just the latest.
        // Gated on the feature toggle and a session flag — DeviceStatusOpenAPS may
        // have already appended the current point above, so we can't use isEmpty here.
        if Storage.shared.displaySmoothedBG.value, !hasFetchedSmoothedBgHistory {
            webLoadNSSmoothedBgHistory()
        }

        if Storage.shared.contactEnabled.value, Storage.shared.contactIOB.value != .off,
           Observable.shared.iobText.value != previousIOBText
        {
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
