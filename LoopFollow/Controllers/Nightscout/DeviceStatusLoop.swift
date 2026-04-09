// LoopFollow
// DeviceStatusLoop.swift

import Charts
import Foundation
import HealthKit
import UIKit

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
