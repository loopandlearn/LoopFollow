// LoopFollow
// StatsDataService.swift

import Foundation

class StatsDataService {
    weak var mainViewController: MainViewController?

    var daysToAnalyze: Int = 14 // Keep for backward compatibility
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    var endDate: Date = .init()

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

    /// Update the date range for analysis
    func updateDateRange(start: Date, end: Date) {
        startDate = start
        endDate = end
        // Also update daysToAnalyze for compatibility with existing code
        let daysBetween = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 14
        daysToAnalyze = max(daysBetween, 1)
    }

    func ensureDataAvailable(onProgress: @escaping () -> Void, completion: @escaping () -> Void) {
        guard let mainVC = mainViewController else {
            completion()
            return
        }

        let cutoffTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970

        let oldestBG = mainVC.statsBGData.filter { $0.date >= cutoffTime && $0.date <= endTime }.min(by: { $0.date < $1.date })?.date
        let oldestBolus = mainVC.statsBolusData.filter { $0.date >= cutoffTime && $0.date <= endTime }.min(by: { $0.date < $1.date })?.date
        let oldestCarb = mainVC.statsCarbData.filter { $0.date >= cutoffTime && $0.date <= endTime }.min(by: { $0.date < $1.date })?.date
        let oldestBasal = mainVC.statsBasalData.filter { $0.date >= cutoffTime && $0.date <= endTime }.min(by: { $0.date < $1.date })?.date

        let bgDataCount = mainVC.statsBGData.filter { $0.date >= cutoffTime && $0.date <= endTime }.count
        let bolusDataCount = mainVC.statsBolusData.filter { $0.date >= cutoffTime && $0.date <= endTime }.count
        let carbDataCount = mainVC.statsCarbData.filter { $0.date >= cutoffTime && $0.date <= endTime }.count
        let basalDataCount = mainVC.statsBasalData.filter { $0.date >= cutoffTime && $0.date <= endTime }.count

        let minExpectedBGEntries = max(daysToAnalyze * 6, 12)
        let hasEnoughBGData = bgDataCount >= minExpectedBGEntries && (oldestBG ?? endTime) <= cutoffTime + (24 * 60 * 60)
        let minExpectedTreatmentEntries = max(daysToAnalyze, 1)
        let hasEnoughTreatmentData = (bolusDataCount + carbDataCount + basalDataCount) >= minExpectedTreatmentEntries &&
            (oldestBolus ?? endTime) <= cutoffTime + (24 * 60 * 60) &&
            (oldestCarb ?? endTime) <= cutoffTime + (24 * 60 * 60) &&
            (oldestBasal ?? endTime) <= cutoffTime + (24 * 60 * 60)

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
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        return mainVC.statsBGData.filter { $0.date >= startTime && $0.date <= endTime }
    }

    func getBolusData() -> [MainViewController.bolusGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        return mainVC.statsBolusData.filter { $0.date >= startTime && $0.date <= endTime }
    }

    func getSMBData() -> [MainViewController.bolusGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        return mainVC.statsSMBData.filter { $0.date >= startTime && $0.date <= endTime }
    }

    func getCarbData() -> [MainViewController.carbGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        return mainVC.statsCarbData.filter { $0.date >= startTime && $0.date <= endTime }
    }

    func getBasalData() -> [MainViewController.basalGraphStruct] {
        guard let mainVC = mainViewController else { return [] }
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        return mainVC.statsBasalData.filter { $0.date >= startTime && $0.date <= endTime }
    }

    func getBasalProfile() -> [MainViewController.basalProfileStruct] {
        guard let mainVC = mainViewController else { return [] }
        return mainVC.basalProfile
    }

    func getTempBasalData() -> [TempBasalEntry] {
        let startTime = startDate.timeIntervalSince1970
        let endTime = endDate.timeIntervalSince1970
        return tempBasalEntries.filter { $0.startTime >= startTime && $0.startTime <= endTime }
    }

    /// Calculate data availability for the current date range
    func getDataAvailability() -> DataAvailabilityInfo {
        let bgData = getBGData()
        return DataAvailabilityCalculator.calculateAvailability(
            bgData: bgData,
            startDate: startDate,
            endDate: endDate
        )
    }
}
