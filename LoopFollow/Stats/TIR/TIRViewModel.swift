// LoopFollow
// TIRViewModel.swift

import Combine
import Foundation

class TIRViewModel: ObservableObject {
    @Published var tirData: [TIRDataPoint] = []
    @Published var showTITR: Bool

    private let dataService: StatsDataService

    init(dataService: StatsDataService) {
        self.dataService = dataService
        showTITR = Storage.shared.showTITR.value
        calculateTIR()
    }

    func calculateTIR() {
        let bgData = dataService.getBGData()
        tirData = TIRCalculator.calculate(bgData: bgData, useTightRange: showTITR)
    }

    func toggleTIRMode() {
        showTITR.toggle()
        Storage.shared.showTITR.value = showTITR
        calculateTIR()
    }

    func clearStats() {
        tirData = []
    }
}
