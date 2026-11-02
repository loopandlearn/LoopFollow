// LoopFollow
// RetroSnapshot.swift

import HealthKit
import SwiftUI

/// What the BG display and info table show while the user scrubs the main
/// chart: the state at the scrubbed time instead of the latest values.
struct RetroSnapshot: Equatable {
    struct Row: Equatable {
        let value: String
        let numericValue: Double?
    }

    let date: Date
    let timeText: String
    let bgText: String
    let bgColor: Color
    let directionText: String
    let deltaText: String
    let predictionText: String
    let predictionColor: Color
    /// Info rows with a value at the scrubbed time; other rows show "—".
    let rows: [InfoType: Row]

    /// Color that marks the displays as showing a past time.
    static let accent = Color(.systemGray)
}

/// Card behind the BG display and info table while they show a past time.
/// It extends past the content into the surrounding spacing, so the text
/// keeps its place and does not touch the card's edge.
struct RetroCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(
                colors: [RetroSnapshot.accent.opacity(0.4), RetroSnapshot.accent.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .padding(EdgeInsets(top: -8, leading: -4, bottom: -4, trailing: -4))
    }
}

/// Publishes the snapshot for the time under the user's finger while
/// scrubbing, and nil otherwise. Only the displays change; alarms, the Live
/// Activity and everything else keep using the latest values.
final class RetroSelection: ObservableObject {
    static let shared = RetroSelection()

    @Published private(set) var snapshot: RetroSnapshot?

    private init() {
        // A touch the system cancels (a call, Notification Center, leaving the
        // app) may never end the scrub; the displays return to live anyway.
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.clear()
            }
        }
    }

    /// Shows the state at `date`, or the live values when nil. `refresh`
    /// rebuilds the snapshot for an unchanged date after new data arrived.
    func select(_ date: Date?, refresh: Bool = false) {
        guard let date, let vc = MainViewController.shared
        else {
            clear()
            return
        }
        guard refresh || snapshot?.date != date else { return }
        snapshot = vc.retroSnapshot(at: date)
    }

    private func clear() {
        if snapshot != nil { snapshot = nil }
    }
}

extension MainViewController {
    /// The BG display and info table values at `date`, a scrub position on the
    /// BG reading grid.
    func retroSnapshot(at date: Date) -> RetroSnapshot {
        let time = date.timeIntervalSince1970
        let history = DeviceStatusHistory.shared
        let sample = history.cycle(forReadingAt: date) ?? history.sample(near: date)

        // BG, direction and delta of the reading at the scrub position.
        var bgText = "—"
        var bgColor = Color.primary
        var directionText = ""
        var deltaText = ""
        // Scrub positions on a reading carry its exact time; slots without one show no BG.
        if let index = bgData.lastIndex(where: { abs($0.date - time) <= 30 }) {
            let reading = bgData[index]
            if reading.sgv <= globalVariables.minDisplayGlucose {
                bgText = "LOW"
            } else if reading.sgv >= globalVariables.maxDisplayGlucose {
                bgText = "HIGH"
            } else {
                bgText = Localizer.toDisplayUnits(String(reading.sgv))
            }
            if Storage.shared.colorBGText.value {
                let thresholds = UnitSettingsStore.shared.effectiveThresholds()
                if Double(reading.sgv) >= thresholds.high {
                    bgColor = .yellow
                } else if Double(reading.sgv) <= thresholds.low {
                    bgColor = .red
                } else {
                    bgColor = .green
                }
            }
            if let direction = reading.direction {
                directionText = bgDirectionGraphic(direction)
            }
            if index > 0 {
                let delta = reading.sgv - bgData[index - 1].sgv
                deltaText = (delta < 0 ? "" : "+") + Localizer.toDisplayUnits(String(delta))
            }
        }

        let isLoopSample = sample?.forecast?.curves[DeviceStatusHistorySample.Forecast.loopCurve] != nil
        let predictionText = sample?.eventualBG.map { Localizer.formatQuantity($0) } ?? ""

        return RetroSnapshot(
            date: date,
            timeText: chartModel.pillTimeString(for: date),
            bgText: bgText,
            bgColor: bgColor,
            directionText: directionText,
            deltaText: deltaText,
            predictionText: predictionText,
            predictionColor: isLoopSample ? .purple : .gray,
            rows: retroRows(at: date, sample: sample)
        )
    }

    private func retroRows(at date: Date, sample: DeviceStatusHistorySample?) -> [InfoType: RetroSnapshot.Row] {
        let time = date.timeIntervalSince1970
        let isLoop = Storage.shared.device.value == "Loop"
        var rows: [InfoType: RetroSnapshot.Row] = [:]

        func set(_ type: InfoType, _ value: String?, _ numeric: Double? = nil) {
            guard let value, !value.isEmpty else { return }
            rows[type] = .init(value: value, numericValue: numeric)
        }

        // Values from the loop cycle's devicestatus record.
        if let sample {
            if let iob = sample.iob, let metric = InsulinMetric(from: ["iob": iob as AnyObject], key: "iob") {
                set(.iob, metric.formattedValue(), iob)
            }
            if let cob = sample.cob, let metric = CarbMetric(from: ["cob": cob as AnyObject], key: "cob") {
                set(.cob, metric.formattedValue(), cob)
            }
            if let tdd = sample.tdd, let metric = InsulinMetric(from: ["TDD": tdd as AnyObject], key: "TDD") {
                set(.tdd, metric.formattedValue(), tdd)
            }
            set(.recBolus, sample.recommendedBolus.map { InsulinFormatter.shared.string($0) }, sample.recommendedBolus)
            set(.battery, sample.uploaderBattery.map { String(format: "%.0f", $0) + "%" }, sample.uploaderBattery)
            set(.pumpBattery, sample.pumpBattery.map { String(format: "%.0f", $0) + "%" }, sample.pumpBattery)
            set(.pump, sample.reservoir.map { String(format: "%.0f", $0) + "U" }, sample.reservoir)
            set(.autosens, sample.sensitivityRatio.map { String(format: "%.0f", $0 * 100) + "%" })
            set(.smoothedBG, sample.smoothedBG.map { Localizer.formatQuantity($0) })
            set(.updated, Localizer.formatTimestampToLocalString(sample.date))
            set(.minMax, retroMinMax(sample.forecast))
            if let override = sample.loopOverride {
                let percent = override.multiplier.map { String(format: "%.0f%%", $0 * 100) } ?? "100%"
                set(.override, "\(percent) (\(Localizer.toDisplayUnits(String(override.minTarget)))-\(Localizer.toDisplayUnits(String(override.maxTarget))))")
            }
        }

        // Profile-based rows, from the loaded profile's schedule at that time
        // of day, with the loop's own value where the record carries one.
        if let profileISF = profileManager.isf(at: date) {
            if let isf = sample?.isf,
               Localizer.formatQuantity(profileISF) != Localizer.formatQuantity(isf)
            {
                set(.isf, "\(Localizer.formatQuantity(profileISF)) \(InfoDataSeparator.arrow.rawValue) \(Localizer.formatQuantity(isf))")
            } else {
                set(.isf, Localizer.formatQuantity(profileISF))
            }
        } else if let isf = sample?.isf {
            set(.isf, Localizer.formatQuantity(isf))
        }

        let profileCR = profileManager.carbRatio(at: date)
        let loopCR = sample?.carbRatio
        if let profileCR, let loopCR, profileCR != loopCR {
            set(.carbRatio, "\(Localizer.formatToLocalizedString(profileCR)) \(InfoDataSeparator.arrow.rawValue) \(Localizer.formatToLocalizedString(loopCR))")
        } else if let cr = profileCR ?? loopCR {
            set(.carbRatio, Localizer.formatToLocalizedString(cr))
        }

        if let target = sample?.target {
            set(.target, Localizer.formatQuantity(target))
        } else if let low = profileManager.targetLow(at: date) {
            let lowText = Localizer.formatQuantity(low)
            if let high = profileManager.targetHigh(at: date), Localizer.formatQuantity(high) != lowText {
                set(.target, "\(lowText) \(InfoDataSeparator.dash.rawValue) \(Localizer.formatQuantity(high))")
            } else {
                set(.target, lowText)
            }
        }

        // Rows that do not depend on the time keep their live value.
        for type in [InfoType.profile, .dbSize] {
            let live = infoManager.tableData[type.rawValue]
            set(type, live.value, live.numericValue)
        }

        // Rows derived from data the chart already holds.
        if let rate = basalData.filter({ $0.date <= time }).max(by: { $0.date < $1.date })?.basalRate {
            let actual = Localizer.formatToLocalizedString(rate, maxFractionDigits: 2, minFractionDigits: 0)
            if let scheduled = profileManager.basal(at: date), scheduled != actual {
                set(.basal, "\(scheduled) \(InfoDataSeparator.arrow.rawValue) \(actual)")
            } else {
                set(.basal, actual)
            }
        }

        if !isLoop,
           let band = overrideGraphData.last(where: { $0.date <= time && time < $0.endDate })
        {
            set(.override, band.reason.isEmpty ? "Override" : band.reason)
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        let carbs = carbData
            .filter { $0.date <= time && calendar.isDate(Date(timeIntervalSince1970: $0.date), inSameDayAs: date) }
            .reduce(0) { $0 + $1.value }
        set(.carbsToday, String(format: "%.0f", carbs), carbs)

        // Site and sensor ages, when the current insert predates the scrubbed time.
        for (type, insertTime) in [
            (InfoType.sage, Storage.shared.sageInsertTime.value),
            (.cage, Storage.shared.cageInsertTime.value),
            (.iage, Storage.shared.iageInsertTime.value),
        ] where insertTime > 0 && insertTime <= time {
            let age = time - insertTime
            set(type, Self.ageFormatter.string(from: age), age / 86400)
        }

        return rows
    }

    /// Min/max of the forecast, as the live row shows it.
    private func retroMinMax(_ forecast: DeviceStatusHistorySample.Forecast?) -> String? {
        guard let forecast else { return nil }
        let values: [Int]
        if let main = forecast.curves[DeviceStatusHistorySample.Forecast.loopCurve] {
            values = main
        } else {
            let count = Int(Storage.shared.predictionToLoad.value * 12) + 1
            values = forecast.curves.values.flatMap { $0.prefix(count) }
        }
        guard let low = values.min(), let high = values.max() else { return nil }
        return "\(Localizer.toDisplayUnits(String(low)))/\(Localizer.toDisplayUnits(String(high)))"
    }

    private static let ageFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.day, .hour]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
