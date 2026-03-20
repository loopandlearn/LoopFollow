// LoopFollow
// TIRViewModel.swift

import Combine
import Foundation

class TIRViewModel: ObservableObject {
    @Published var tirData: [TIRDataPoint] = []
    @Published var showTITR: Bool {
        didSet {
            UnitSettingsStore.shared.timeInRangeMode = showTITR ? .titr : .tir
        }
    }

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
        showTITR = UnitSettingsStore.shared.timeInRangeMode == .titr
        calculateTIR()
    }

    func calculateTIR() {
        let bgData = dataService.getBGData()
        tirData = TIRCalculator.calculate(bgData: bgData, useTightRange: showTITR)
    }

    func toggleTIRMode() {
        showTITR.toggle()
        calculateTIR()
    }

    func clearStats() {
        tirData = []
    }
}
