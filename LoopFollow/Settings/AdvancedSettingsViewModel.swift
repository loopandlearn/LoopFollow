// LoopFollow
// AdvancedSettingsViewModel.swift

import Foundation

class AdvancedSettingsViewModel: ObservableObject {
    @Published var downloadTreatments: Bool {
        didSet {
            Storage.shared.downloadTreatments.value = downloadTreatments
        }
    }

    @Published var downloadPrediction: Bool {
        didSet {
            Storage.shared.downloadPrediction.value = downloadPrediction
        }
    }

    @Published var graphBasal: Bool {
        didSet {
            Storage.shared.graphBasal.value = graphBasal
        }
    }

    @Published var graphBolus: Bool {
        didSet {
            Storage.shared.graphBolus.value = graphBolus
        }
    }

    @Published var graphCarbs: Bool {
        didSet {
            Storage.shared.graphCarbs.value = graphCarbs
        }
    }

    @Published var graphOtherTreatments: Bool {
        didSet {
            Storage.shared.graphOtherTreatments.value = graphOtherTreatments
        }
    }

    @Published var bgUpdateDelay: Int {
        didSet {
            Storage.shared.bgUpdateDelay.value = bgUpdateDelay
        }
    }

    @Published var debugLogLevel: Bool {
        didSet {
            Storage.shared.debugLogLevel.value = debugLogLevel
        }
    }

    init() {
        downloadTreatments = Storage.shared.downloadTreatments.value
        downloadPrediction = Storage.shared.downloadPrediction.value
        graphBasal = Storage.shared.graphBasal.value
        graphBolus = Storage.shared.graphBolus.value
        graphCarbs = Storage.shared.graphCarbs.value
        graphOtherTreatments = Storage.shared.graphOtherTreatments.value
        bgUpdateDelay = Storage.shared.bgUpdateDelay.value
        debugLogLevel = Storage.shared.debugLogLevel.value
    }
}
