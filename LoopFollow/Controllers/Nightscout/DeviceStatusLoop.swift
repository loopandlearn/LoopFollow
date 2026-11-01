// LoopFollow
// DeviceStatusLoop.swift

import Foundation
import HealthKit
import SwiftUI

extension MainViewController {
    func DeviceStatusLoop(formatter: ISO8601DateFormatter, lastLoopRecord: [String: AnyObject]) {
        Storage.shared.device.value = "Loop"
        Storage.shared.loopRemoteCommands.value = (lastLoopRecord["testingDetails"] as? [String: AnyObject])?["remoteCommands"] as? [String] ?? []

        if Storage.shared.remoteType.value == .trc {
            Storage.shared.remoteType.value = .none
        }

        let previousLastLoopTime = Observable.shared.previousAlertLastLoopTime.value ?? 0
        let lastLoopTime = Observable.shared.alertLastLoopTime.value ?? 0

        // Loop reports IOB and COB even when the loop failed.
        if let insulinMetric = InsulinMetric(from: lastLoopRecord["iob"], key: "iob") {
            infoManager.updateInfoData(type: .iob, value: insulinMetric)
            latestIOB = insulinMetric
            Observable.shared.iobText.value = insulinMetric.formattedValue()
        }

        if let cobMetric = CarbMetric(from: lastLoopRecord["cob"], key: "cob") {
            infoManager.updateInfoData(type: .cob, value: cobMetric)
            latestCOB = cobMetric
        }

        Storage.shared.lastIOB.value = latestIOB?.value
        Storage.shared.lastCOB.value = latestCOB?.value

        if let failureReason = lastLoopRecord["failureReason"], !(failureReason is NSNull) {
            Observable.shared.loopStatusText.value = "X"
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

            if let predictdata = lastLoopRecord["predicted"] as? [String: AnyObject],
               let prediction = predictdata["values"] as? [Double],
               let lastPrediction = prediction.last
            {
                Observable.shared.predictionText.value = Localizer.toDisplayUnits(String(Int(round(lastPrediction))))
                Observable.shared.predictionColor.value = .purple
                if Storage.shared.downloadPrediction.value, previousLastLoopTime < lastLoopTime || predictionData.isEmpty {
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
                infoManager.updateInfoData(type: .recBolus, value: InsulinFormatter.shared.string(recBolus), numericValue: recBolus)
                Observable.shared.deviceRecBolus.value = recBolus
                let cycleTime = (lastLoopRecord["timestamp"] as? String).flatMap { formatter.date(from: $0)?.timeIntervalSince1970 }
                Observable.shared.deviceRecBolusAt.value = cycleTime ?? lastLoopTime
            } else {
                infoManager.clearInfoData(type: .recBolus)
                Observable.shared.deviceRecBolus.value = nil
                Observable.shared.deviceRecBolusAt.value = nil
            }
            // Loop uploads its Closed Loop toggle as loopSettings.dosingEnabled in the profile
            if profileManager.loopDosingEnabled == false {
                Observable.shared.loopStatusText.value = "⏀"
                latestLoopStatusString = "⏀"
            } else if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String: AnyObject] {
                if let tempBasalString = loopStatus["timestamp"] as? String,
                   let tempBasalTime = formatter.date(from: tempBasalString)?.timeIntervalSince1970
                {
                    var lastBGTime = lastLoopTime
                    if bgData.count > 0 {
                        lastBGTime = bgData[bgData.count - 1].date
                    }
                    if tempBasalTime > lastBGTime, !wasEnacted {
                        Observable.shared.loopStatusText.value = "⏀"
                        latestLoopStatusString = "⏀"
                    } else {
                        Observable.shared.loopStatusText.value = "↻"
                        latestLoopStatusString = "↻"
                    }
                }
            } else {
                Observable.shared.loopStatusText.value = "↻"
                latestLoopStatusString = "↻"
            }

            // Live Activity storage
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
