// LoopFollow
// StatsDataService.swift

import Foundation

class StatsDataService {
    weak var mainViewController: MainViewController?

    var daysToAnalyze: Int = 14
    private let dataFetcher: StatsDataFetcher

    /// Stores raw temp basal entries with rate and duration
    var tempBasalEntries: [TempBasalEntry] = []

    /// Structure to hold temp basal data for calculations
    struct TempBasalEntry {
        let rate: Double // U/hr (absolute rate)
        let startTime: TimeInterval // Unix timestamp
        let durationMinutes: Double // Duration in minutes
    }

    init(mainViewController: MainViewController?) {
        self.mainViewController = mainViewController
        dataFetcher = StatsDataFetcher(mainViewController: mainViewController)
        dataFetcher.dataService = self
    }

    func ensureDataAvailable(onProgress: @escaping () -> Void, completion: @escaping () -> Void) {
        guard let mainVC = mainViewController else {
            completion()
            return
        }

        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        let now = Date().timeIntervalSince1970

        let oldestBG = mainVC.statsBGData.filter { $0.date >= cutoffTime && $0.date <= now }.min(by: { $0.date < $1.date })?.date
        let oldestBolus = mainVC.statsBolusData.filter { $0.date >= cutoffTime && $0.date <= now }.min(by: { $0.date < $1.date })?.date
        let oldestCarb = mainVC.statsCarbData.filter { $0.date >= cutoffTime && $0.date <= now }.min(by: { $0.date < $1.date })?.date
        let oldestBasal = mainVC.statsBasalData.filter { $0.date >= cutoffTime && $0.date <= now }.min(by: { $0.date < $1.date })?.date

        let bgDataCount = mainVC.statsBGData.filter { $0.date >= cutoffTime && $0.date <= now }.count
        let bolusDataCount = mainVC.statsBolusData.filter { $0.date >= cutoffTime && $0.date <= now }.count
        let carbDataCount = mainVC.statsCarbData.filter { $0.date >= cutoffTime && $0.date <= now }.count
        let basalDataCount = mainVC.statsBasalData.filter { $0.date >= cutoffTime && $0.date <= now }.count

        let minExpectedBGEntries = max(daysToAnalyze * 6, 12)
        let hasEnoughBGData = bgDataCount >= minExpectedBGEntries && (oldestBG ?? now) <= cutoffTime + (24 * 60 * 60)
        let minExpectedTreatmentEntries = max(daysToAnalyze, 1)
        let hasEnoughTreatmentData = (bolusDataCount + carbDataCount + basalDataCount) >= minExpectedTreatmentEntries &&
            (oldestBolus ?? now) <= cutoffTime + (24 * 60 * 60) &&
            (oldestCarb ?? now) <= cutoffTime + (24 * 60 * 60) &&
            (oldestBasal ?? now) <= cutoffTime + (24 * 60 * 60)

        if !hasEnoughBGData {
            dataFetcher.fetchBGData(days: daysToAnalyze) {
                DispatchQueue.main.async {
                    onProgress()
                }

                if !hasEnoughTreatmentData {
                    self.dataFetcher.fetchTreatmentsData(days: self.daysToAnalyze) {
                        DispatchQueue.main.async {
                            onProgress()
                            completion()
                        }
                    }
                } else {
                    completion()
                }
            }
        } else if !hasEnoughTreatmentData {
            dataFetcher.fetchTreatmentsData(days: daysToAnalyze) {
                DispatchQueue.main.async {
                    onProgress()
                    completion()
                }
            }
        } else {
            completion()
        }
    }

    func getBGData() -> [ShareGlucoseData] {
        guard let mainVC = mainViewController else { return [] }
        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        return mainVC.statsBGData.filter { $0.date >= cutoffTime }
    }

    func getBolusData() -> [MainViewController.bolusGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        return mainVC.statsBolusData.filter { $0.date >= cutoffTime }
    }

    func getSMBData() -> [MainViewController.bolusGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        return mainVC.statsSMBData.filter { $0.date >= cutoffTime }
    }

    func getCarbData() -> [MainViewController.carbGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        let now = Date().timeIntervalSince1970
        return mainVC.statsCarbData.filter { $0.date >= cutoffTime && $0.date <= now }
    }

    func getBasalData() -> [MainViewController.basalGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        return mainVC.statsBasalData.filter { $0.date >= cutoffTime }
    }

    func getBasalProfile() -> [MainViewController.basalProfileStruct] {
        guard let mainVC = mainViewController else { return [] }
        return mainVC.basalProfile
    }

    func getTempBasalData() -> [TempBasalEntry] {
        let cutoffTime = Date().timeIntervalSince1970 - (Double(daysToAnalyze) * 24 * 60 * 60)
        return tempBasalEntries.filter { $0.startTime >= cutoffTime }
    }
}
