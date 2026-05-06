// LoopFollow
// DeviceStatusLoop.swift

import Charts
import Foundation
import HealthKit
import UIKit

extension MainViewController {
    /// Calculates Loop TDD from treatment arrays and updates the info table.
    /// Called both from DeviceStatusLoop and after treatments load, since device
    /// status typically completes before treatments on first launch.
    func updateLoopTDD() {
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        let oneDayAgo = now - (24 * 60 * 60)

        let bolusIn24h = bolusData.filter { $0.date >= oneDayAgo }
        let smbIn24h   = smbData.filter { $0.date >= oneDayAgo }
        let bolusUnits = bolusIn24h.reduce(0.0) { $0 + $1.value }
        let smbUnits   = smbIn24h.reduce(0.0) { $0 + $1.value }
        let bolusTotal = bolusUnits + smbUnits

        var basalTotal = 0.0
        var scheduledPrefixTotal = 0.0

        let basalWindowStart = basalData.first.map { max($0.date, oneDayAgo) } ?? oneDayAgo
        if basalWindowStart > oneDayAgo {
            scheduledPrefixTotal = scheduledBasalInWindow(from: oneDayAgo, to: basalWindowStart)
            basalTotal += scheduledPrefixTotal
        }

        var lastIntegratedEnd = basalWindowStart
        for i in basalData.indices.dropLast() {
            let segStart = max(basalData[i].date, oneDayAgo)
            let segEnd   = min(basalData[i + 1].date, now)
            guard segEnd > segStart, segStart >= lastIntegratedEnd else { continue }
            basalTotal += basalData[i].basalRate * (segEnd - segStart) / 3600.0
            lastIntegratedEnd = segEnd
        }

        let tddValue = bolusTotal + basalTotal
        LogManager.shared.log(
            category: .deviceStatus,
            message: String(format:
                "TDD calc: bolus=%d×%.2fU smb=%d×%.2fU basalEntries=%d scheduledPrefix=%.2fU basal=%.2fU → TDD=%.2fU",
                bolusIn24h.count, bolusUnits,
                smbIn24h.count, smbUnits,
                basalData.count, scheduledPrefixTotal, basalTotal,
                tddValue),
            isDebug: true
        )

        if tddValue > 0 {
            infoManager.updateInfoData(type: .tdd, value: tddValue, maxFractionDigits: 2, minFractionDigits: 0)
        }
    }

    private func scheduledBasalInWindow(from startTime: TimeInterval, to endTime: TimeInterval) -> Double {
        guard !basalProfile.isEmpty, endTime > startTime else { return 0.0 }
        let sorted = basalProfile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }
        let calendar = dateTimeUtils.displayCalendar()
        var total = 0.0
        var current = startTime
        while current < endTime {
            let dayStart = calendar.startOfDay(for: Date(timeIntervalSince1970: current)).timeIntervalSince1970
            for i in 0 ..< sorted.count {
                let segStart = dayStart + sorted[i].timeAsSeconds
                let segEnd = i < sorted.count - 1 ? dayStart + sorted[i + 1].timeAsSeconds : dayStart + 86400
                let clampedStart = max(current, segStart)
                let clampedEnd = min(endTime, segEnd)
                if clampedEnd > clampedStart {
                    total += sorted[i].value * (clampedEnd - clampedStart) / 3600.0
                }
            }
            current = dayStart + 86400
        }
        return total
    }
}

extension MainViewController {
    func DeviceStatusLoop(formatter: ISO8601DateFormatter, lastLoopRecord: [String: AnyObject]) {
        Storage.shared.device.value = "Loop"

        if Storage.shared.remoteType.value == .trc {
            Storage.shared.remoteType.value = .none
        }

        let previousLastLoopTime = Observable.shared.previousAlertLastLoopTime.value ?? 0
        let lastLoopTime = Observable.shared.alertLastLoopTime.value ?? 0

        if lastLoopRecord["failureReason"] != nil {
            LoopStatusLabel.text = "X"
            latestLoopStatusString = "X"
        } else {
            var wasEnacted = false
            if lastLoopRecord["enacted"] is [String: AnyObject] {
                wasEnacted = true
            }

            // ISF
            let profileISF = profileManager.currentISF()
            if let profileISF = profileISF {
                infoManager.updateInfoData(type: .isf, value: profileISF)
                Storage.shared.lastIsfMgdlPerU.value = profileISF.doubleValue(for: .milligramsPerDeciliter)
            }

            // Carb Ratio (CR)
            let profileCR = profileManager.currentCarbRatio()
            if let profileCR = profileCR {
                infoManager.updateInfoData(type: .carbRatio, value: profileCR)
                Storage.shared.lastCarbRatio.value = profileCR
            }

            // Target
            let profileTargetLow = profileManager.currentTargetLow()
            let profileTargetHigh = profileManager.currentTargetHigh()

            if let profileTargetLow = profileTargetLow, let profileTargetHigh = profileTargetHigh, profileTargetLow != profileTargetHigh {
                infoManager.updateInfoData(type: .target, firstValue: profileTargetLow, secondValue: profileTargetHigh, separator: .dash)
            } else if let profileTargetLow = profileTargetLow {
                infoManager.updateInfoData(type: .target, value: profileTargetLow)
            }
            Storage.shared.lastTargetLowMgdl.value = profileTargetLow?.doubleValue(for: .milligramsPerDeciliter)
            Storage.shared.lastTargetHighMgdl.value = profileTargetHigh?.doubleValue(for: .milligramsPerDeciliter)

            // IOB
            if let insulinMetric = InsulinMetric(from: lastLoopRecord["iob"], key: "iob") {
                infoManager.updateInfoData(type: .iob, value: insulinMetric)
                latestIOB = insulinMetric
                Observable.shared.iobText.value = insulinMetric.formattedValue()
            }

            // COB
            if let cobMetric = CarbMetric(from: lastLoopRecord["cob"], key: "cob") {
                infoManager.updateInfoData(type: .cob, value: cobMetric)
                latestCOB = cobMetric
            }

            if let predictdata = lastLoopRecord["predicted"] as? [String: AnyObject] {
                let prediction = predictdata["values"] as! [Double]
                PredictionLabel.text = Localizer.toDisplayUnits(String(Int(round(prediction.last!))))
                PredictionLabel.textColor = UIColor.systemPurple
                if Storage.shared.downloadPrediction.value, previousLastLoopTime < lastLoopTime {
                    predictionData.removeAll()
                    var predictionTime = lastLoopTime
                    let toLoad = Int(Storage.shared.predictionToLoad.value * 12)
                    var i = 0
                    while i <= toLoad {
                        if i < prediction.count {
                            let sgvValue = Int(round(prediction[i]))
                            let clampedValue = min(max(sgvValue, globalVariables.minDisplayGlucose), globalVariables.maxDisplayGlucose)
                            let prediction = ShareGlucoseData(sgv: clampedValue, date: predictionTime, direction: "flat")
                            predictionData.append(prediction)
                            predictionTime += 300
                        }
                        i += 1
                    }

                    if let predMin = prediction.min(), let predMax = prediction.max() {
                        let formattedMin = Localizer.toDisplayUnits(String(predMin))
                        let formattedMax = Localizer.toDisplayUnits(String(predMax))
                        let value = "\(formattedMin)/\(formattedMax)"
                        infoManager.updateInfoData(type: .minMax, value: value)
                        Storage.shared.lastMinBgMgdl.value = predMin
                        Storage.shared.lastMaxBgMgdl.value = predMax
                    }

                    updatePredictionGraph()
                }
            } else {
                predictionData.removeAll()
                infoManager.clearInfoData(type: .minMax)
                updatePredictionGraph()
            }
            if let recBolus = lastLoopRecord["recommendedBolus"] as? Double {
                let formattedRecBolus = String(format: "%.2fU", recBolus)
                infoManager.updateInfoData(type: .recBolus, value: formattedRecBolus)
                Observable.shared.deviceRecBolus.value = recBolus
            }
            if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String: AnyObject] {
                if let tempBasalTime = formatter.date(from: (loopStatus["timestamp"] as! String))?.timeIntervalSince1970 {
                    var lastBGTime = lastLoopTime
                    if bgData.count > 0 {
                        lastBGTime = bgData[bgData.count - 1].date
                    }
                    if tempBasalTime > lastBGTime, !wasEnacted {
                        LoopStatusLabel.text = "⏀"
                        latestLoopStatusString = "⏀"
                    } else {
                        LoopStatusLabel.text = "↻"
                        latestLoopStatusString = "↻"
                    }
                }
            } else {
                LoopStatusLabel.text = "↻"
                latestLoopStatusString = "↻"
            }

            // Live Activity storage
            Storage.shared.lastIOB.value = latestIOB?.value
            Storage.shared.lastCOB.value = latestCOB?.value
            if let predictdata = lastLoopRecord["predicted"] as? [String: AnyObject],
               let values = predictdata["values"] as? [Double]
            {
                Storage.shared.projectedBgMgdl.value = values.last
            } else {
                Storage.shared.projectedBgMgdl.value = nil
            }
        }
    }
}
