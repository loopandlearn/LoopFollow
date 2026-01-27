// LoopFollow
// GRIViewModel.swift

import Combine
import Foundation

class GRIViewModel: ObservableObject {
    @Published var gri: Double?
    @Published var griHypoComponent: Double?
    @Published var griHyperComponent: Double?
    @Published var griDataPoints: [(date: Date, value: Double)] = []

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
        calculateGRI()
    }

    func calculateGRI() {
        let bgData = dataService.getBGData()
        guard !bgData.isEmpty else { return }

        let result = GRICalculator.calculate(bgData: bgData)
        gri = result.gri
        griHypoComponent = result.hypoComponent
        griHyperComponent = result.hyperComponent

        griDataPoints = GRICalculator.calculateTimeSeries(bgData: bgData)
    }
}
