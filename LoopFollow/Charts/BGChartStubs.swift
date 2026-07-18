// LoopFollow
// BGChartStubs.swift

import Foundation
import SwiftUI
import UIKit

/// The `update*Graph()` / `createGraph()` entry points the rest of the app
/// calls to refresh the chart. Rendering happens in BGChartModel +
/// BGChartView (Apple Swift Charts); these update lightweight state
/// (topBG / topPredictionBG / prediction arrays) and trigger a (coalesced)
/// model rebuild.
extension MainViewController {
    func createGraph() {
        chartModel.rebuild()
        // The chart's follow/auto-return logic runs off model.now, so arm the
        // once-a-minute "now" tick.
        startGraphNowTimer()
    }

    func createSmallBGGraph() {}

    func updateBGGraphSettings() {
        chartModel.rebuild()
    }

    private func recomputeTopBG() {
        let maxBGOffset: Double = 50
        topBG = Storage.shared.minBGScale.value
        for entry in bgData {
            if Double(entry.sgv) > topBG - maxBGOffset {
                topBG = Double(entry.sgv) + maxBGOffset
            }
        }
    }

    private func recomputeTopPredictionBG() {
        let maxBGOffset: Double = 20
        topPredictionBG = Storage.shared.minBGScale.value
        let allPredictions = predictionData + ztPredictionData + iobPredictionData + cobPredictionData + uamPredictionData
        for entry in allPredictions {
            let v = Double(entry.sgv)
            if v > topPredictionBG - maxBGOffset {
                topPredictionBG = v + maxBGOffset
            }
        }
    }

    func updateBGGraph() {
        recomputeTopBG()
        // Profile processing defers building the scheduled-basal segments until
        // the first BG render has happened (Profile.swift checks firstGraphLoad).
        // Clear the flag here or the scheduled basal line never gets data.
        if !bgData.isEmpty {
            firstGraphLoad = false
        }
        chartModel.rebuild()
    }

    func updatePredictionGraph(color _: UIColor? = nil) {
        recomputeTopPredictionBG()
        chartModel.rebuild()
    }

    func updatePredictionGraphGeneric(
        dataIndex: Int,
        predictionData: [ShareGlucoseData],
        chartLabel _: String,
        color _: UIColor
    ) {
        switch dataIndex {
        case 12: ztPredictionData = predictionData
        case 13: iobPredictionData = predictionData
        case 14: cobPredictionData = predictionData
        case 15: uamPredictionData = predictionData
        default: break
        }
        recomputeTopPredictionBG()
        chartModel.rebuild()
    }

    // Removes the Loop forecast line. Used when the active system switches away from Loop.
    func clearLoopPredictionGraph() {
        guard !predictionData.isEmpty else { return }
        predictionData.removeAll()
        updatePredictionGraph()
    }

    // Removes the Trio/OpenAPS forecast (ZT/IOB/COB/UAM lines and the cone). Used when the active system switches away from Trio/OpenAPS.
    func clearOpenAPSPredictionGraph() {
        let hasLineData = !ztPredictionData.isEmpty || !iobPredictionData.isEmpty || !cobPredictionData.isEmpty || !uamPredictionData.isEmpty
        guard hasLineData || !chartModel.cone.isEmpty else { return }
        ztPredictionData = []
        iobPredictionData = []
        cobPredictionData = []
        uamPredictionData = []
        chartModel.cone = []
        recomputeTopPredictionBG()
        chartModel.rebuild()
    }

    // Routes OpenAPS/Trio predictions either into a cone band or individual
    // prediction lines. Cone is only for OpenAPS-based backends; Loop always
    // uses lines.
    func updateOpenAPSPredictionDisplay() {
        guard let predBGs = openAPSPredBGs else {
            chartModel.cone = []
            return
        }

        let displayType: PredictionDisplayType = Storage.shared.device.value == "Loop"
            ? .lines
            : Storage.shared.predictionDisplayType.value
        let toLoad = Int(Storage.shared.predictionToLoad.value * 12)
        let predictionStart = openAPSPredUpdatedTime ?? Date().timeIntervalSince1970
        let types = ["ZT", "IOB", "COB", "UAM"]
        let minDisplay = globalVariables.minDisplayGlucose
        let maxDisplay = globalVariables.maxDisplayGlucose

        topPredictionBG = Storage.shared.minBGScale.value

        if displayType == .cone {
            // Clear individual prediction lines.
            ztPredictionData = []
            iobPredictionData = []
            cobPredictionData = []
            uamPredictionData = []

            let allArrays = types.compactMap { predBGs[$0] }.filter { !$0.isEmpty }
            var coneData: [BGChartModel.ConePoint] = []
            if !allArrays.isEmpty {
                // Cap at the shortest predBG array length so every cone point uses
                // the same set of contributing arrays. Matches Trio's ForecastSetup.
                let coneLength = min(allArrays.map { $0.count }.min()!, toLoad + 1)
                var t = predictionStart
                for i in 0 ..< coneLength {
                    let valuesAtIndex = allArrays.compactMap { i < $0.count ? $0[i] : nil }
                    if !valuesAtIndex.isEmpty {
                        var yMin = max(valuesAtIndex.min()!, Double(minDisplay))
                        var yMax = min(valuesAtIndex.max()!, Double(maxDisplay))
                        // Keep a minimum ±1 mg/dL band so the cone stays visible when predictions agree.
                        if yMin == yMax {
                            yMin -= 1
                            yMax += 1
                        }
                        coneData.append(BGChartModel.ConePoint(
                            date: Date(timeIntervalSince1970: t),
                            yMin: yMin,
                            yMax: yMax
                        ))
                        if yMax > topPredictionBG - 20 { topPredictionBG = yMax + 20 }
                    }
                    t += 300
                }
            }
            chartModel.cone = coneData
        } else {
            chartModel.cone = []

            // dataIndex mapping matches updatePredictionGraphGeneric: 12=ZT 13=IOB 14=COB 15=UAM
            for (offset, type) in types.enumerated() {
                var predictionData: [ShareGlucoseData] = []
                if let graphData = predBGs[type] {
                    var t = predictionStart
                    for i in 0 ... toLoad where i < graphData.count {
                        let clamped = min(max(Int(round(graphData[i])), minDisplay), maxDisplay)
                        predictionData.append(ShareGlucoseData(sgv: clamped, date: t, direction: "flat"))
                        t += 300
                    }
                }
                updatePredictionGraphGeneric(dataIndex: 12 + offset, predictionData: predictionData, chartLabel: type, color: .clear)
            }
        }

        chartModel.rebuild()
    }

    func updateBasalGraph() { chartModel.rebuild() }
    func updateBolusGraph() { chartModel.rebuild() }
    func updateCarbGraph() { chartModel.rebuild() }
    func updateBasalScheduledGraph() { chartModel.rebuild() }
    func updateOverrideGraph() { chartModel.rebuild() }
    func updateBGCheckGraph() { chartModel.rebuild() }
    func updateSuspendGraph() { chartModel.rebuild() }
    func updateResumeGraph() { chartModel.rebuild() }
    func updateSensorStart() { chartModel.rebuild() }
    func updateNotes() { chartModel.rebuild() }
    func updateSmbGraph() { chartModel.rebuild() }
    func updateTempTargetGraph() { chartModel.rebuild() }
}
