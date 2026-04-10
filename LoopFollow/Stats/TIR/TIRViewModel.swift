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
        let mode = UnitSettingsStore.shared.timeInRangeMode
        switch mode {
        case .tir:
            UnitSettingsStore.shared.timeInRangeMode = .titr
        case .titr:
            UnitSettingsStore.shared.timeInRangeMode = .custom
        case .custom:
            UnitSettingsStore.shared.timeInRangeMode = .tir
        }
        calculateTIR()
    }

    func clearStats() {
        tirData = []
    }
}
