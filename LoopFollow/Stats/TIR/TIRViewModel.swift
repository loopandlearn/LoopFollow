// LoopFollow
// TIRViewModel.swift

import Combine
import Foundation

class TIRViewModel: ObservableObject {
    @Published var tirData: [TIRDataPoint] = []

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
        calculateTIR()
    }

    func calculateTIR() {
        let bgData = dataService.getBGData()
        tirData = TIRCalculator.calculate(bgData: bgData)
    }

    func toggleTIRMode() {
        UnitSettingsStore.shared.timeInRangeMode = UnitSettingsStore.shared.timeInRangeMode.next
        calculateTIR()
    }

    func clearStats() {
        tirData = []
    }
}
