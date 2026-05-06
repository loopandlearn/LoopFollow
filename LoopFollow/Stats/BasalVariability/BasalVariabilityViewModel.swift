// LoopFollow
// BasalVariabilityViewModel.swift

import Combine
import Foundation

class BasalVariabilityViewModel: ObservableObject {
    @Published var data: [BasalVariabilityDataPoint] = []

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
        calculate()
    }

    func calculate() {
        let basalData = dataService.getBasalData()
        let profile = dataService.getBasalProfile()
        guard !basalData.isEmpty, !profile.isEmpty else {
            data = []
            return
        }
        data = BasalVariabilityCalculator.calculate(
            basalData: basalData,
            basalProfile: profile,
            startTime: dataService.startDate.timeIntervalSince1970,
            endTime: dataService.endDate.timeIntervalSince1970
        )
    }

    func clearStats() {
        data = []
    }
}
