// LoopFollow
// AlarmTask.swift

import Foundation

extension MainViewController {
    func scheduleAlarmTask(initialDelay: TimeInterval = 30) {
        let firstRun = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .alarmCheck, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.alarmTaskAction()
        }
    }

    func alarmTaskAction() {
        DispatchQueue.main.async {
            let now = Date().timeIntervalSince1970
            let latestOverrideStart = self.overrideGraphData.last { $0.date <= now }?.date
            let latestOverrideEnd = self.overrideGraphData.last { $0.endDate <= now }?.endDate
            let latestTempTargetStart = self.tempTargetGraphData.last { $0.date <= now }?.date
            let latestTempTargetEnd = self.tempTargetGraphData.last { $0.endDate <= now }?.endDate
            let recBolus = Observable.shared.deviceRecBolus.value
            let COB = self.latestCOB?.value
            let sensorInsertedAt = Storage.shared.sageInsertTime.value
            let pumpInsertTime = Storage.shared.cageInsertTime.value
            let latestPumpVol = self.latestPumpVolume
            let bolusEntries = self.bolusData.map { BolusEntry(units: $0.value, date: Date(timeIntervalSince1970: $0.date)) }
            let latestBattery = Observable.shared.deviceBatteryLevel.value
            let latestPumpBattery = Observable.shared.pumpBatteryLevel.value
            let recentCarbs: [CarbSample] = self.carbData.map { CarbSample(grams: $0.value, date: Date(timeIntervalSince1970: $0.date)) }

            let alarmData = AlarmData(
                bgReadings: self.bgData
                    .suffix(24)
                    .map { GlucoseValue(sgv: $0.sgv, date: Date(timeIntervalSince1970: $0.date)) }, /// These are oldest .. newest
                predictionData: self.alarmPredictionData(), /// These are oldest .. newest
                expireDate: Storage.shared.expirationDate.value,
                lastLoopTime: Observable.shared.alertLastLoopTime.value,
                latestOverrideStart: latestOverrideStart,
                latestOverrideEnd: latestOverrideEnd,
                latestTempTargetStart: latestTempTargetStart,
                latestTempTargetEnd: latestTempTargetEnd,
                recBolus: recBolus,
                COB: COB,
                sageInsertTime: sensorInsertedAt,
                pumpInsertTime: pumpInsertTime,
                latestPumpVolume: latestPumpVol,
                IOB: self.latestIOB?.value,
                recentBoluses: bolusEntries,
                latestBattery: latestBattery,
                latestPumpBattery: latestPumpBattery,
                batteryHistory: self.deviceBatteryData,
                recentCarbs: recentCarbs
            )

            let finalAlarmData: AlarmData
            if Observable.shared.debug.value {
                self.saveLatestAlarmDataToFile(alarmData)
                finalAlarmData = self.loadTestAlarmData() ?? alarmData
            } else {
                finalAlarmData = alarmData
            }

            LogManager.shared.log(category: .alarm, message: "Checking alarms based on \(finalAlarmData)", isDebug: true)
            LogManager.shared.log(category: .alarm, message: "Alarms \(Storage.shared.alarms.value)", isDebug: true)

            AlarmManager.shared.checkAlarms(data: finalAlarmData)

            TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(60))
        }
    }

    /// Builds the forward glucose series the low alarm looks ahead in,
    /// oldest .. newest at 5-minute spacing.
    ///
    /// Loop reports a single forecast, already stored in `predictionData`. Trio
    /// reports four forecasts, collapsed into the lowest value per point in time
    /// by `lowestForecast(forecasts:start:cap:)`.
    func alarmPredictionData() -> [GlucoseValue] {
        if Storage.shared.device.value == "Loop" {
            return predictionData
                .prefix(MainViewController.alarmForecastPointCap)
                .map { GlucoseValue(sgv: $0.sgv, date: Date(timeIntervalSince1970: $0.date)) }
        }

        guard let predBGs = openAPSPredBGs else { return [] }

        let forecasts = ["ZT", "IOB", "COB", "UAM"].compactMap { predBGs[$0] }
        return MainViewController.lowestForecast(
            forecasts: forecasts,
            start: openAPSPredUpdatedTime ?? Date().timeIntervalSince1970
        )
    }

    /// Maximum number of forward points (5-minute spacing) the low alarm looks at:
    /// 12 points = 60 minutes, matching the predictive look-ahead's upper bound.
    static let alarmForecastPointCap = 12

    /// Collapses several forecasts into a single series by taking the **lowest**
    /// value at each point in time, oldest .. newest at 5-minute spacing.
    ///
    /// Trio/OpenAPS reports four forecasts (ZT, IOB, COB, UAM) rather than the
    /// single one Loop provides, so this lets the predictive-low alarm fire if
    /// *any* forecast dips to or below the threshold. Empty forecasts are ignored,
    /// and each point uses whichever forecasts still extend that far.
    static func lowestForecast(
        forecasts: [[Double]],
        start: TimeInterval,
        cap: Int = alarmForecastPointCap
    ) -> [GlucoseValue] {
        let nonEmpty = forecasts.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return [] }

        let count = min(nonEmpty.map { $0.count }.max() ?? 0, cap)

        return (0 ..< count).compactMap { i in
            let valuesAtIndex = nonEmpty.compactMap { i < $0.count ? $0[i] : nil }
            guard let lowest = valuesAtIndex.min() else { return nil }
            return GlucoseValue(
                sgv: Int(lowest.rounded()),
                date: Date(timeIntervalSince1970: start + Double(i) * 300)
            )
        }
    }

    func saveLatestAlarmDataToFile(_ alarmData: AlarmData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(alarmData)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("latestAlarmData.json")
            try data.write(to: url)
        } catch {
            LogManager.shared.log(category: .alarm, message: "Failed to save latest AlarmData: \(error)", isDebug: true)
        }
    }

    func loadTestAlarmData() -> AlarmData? {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("testAlarmData.json")

        if fileManager.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let alarmData = try decoder.decode(AlarmData.self, from: data)
                LogManager.shared.log(category: .alarm, message: "Loaded test AlarmData from \(url.path)", isDebug: true)
                return alarmData
            } catch {
                LogManager.shared.log(category: .alarm, message: "Failed to load test AlarmData: \(error)", isDebug: true)
            }
        }
        return nil
    }
}
