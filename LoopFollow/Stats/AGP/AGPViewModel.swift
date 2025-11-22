// LoopFollow
// AGPViewModel.swift

import Combine
import Foundation

class AGPViewModel: ObservableObject {
    @Published var agpData: [AGPDataPoint] = []

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
        calculateAGP()
    }

    func calculateAGP() {
        let bgData = dataService.getBGData()
        agpData = AGPCalculator.calculate(bgData: bgData)
    }
}
