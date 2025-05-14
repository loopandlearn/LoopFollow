//
//  AdvancedSettingsViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-23.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

class AdvancedSettingsViewModel: ObservableObject {
    @Published var downloadTreatments: Bool {
        didSet {
            UserDefaultsRepository.downloadTreatments.value = downloadTreatments
        }
    }

    @Published var downloadPrediction: Bool {
        didSet {
            UserDefaultsRepository.downloadPrediction.value = downloadPrediction
        }
    }

    @Published var graphBasal: Bool {
        didSet {
            UserDefaultsRepository.graphBasal.value = graphBasal
        }
    }

    @Published var graphBolus: Bool {
        didSet {
            UserDefaultsRepository.graphBolus.value = graphBolus
        }
    }

    @Published var graphCarbs: Bool {
        didSet {
            UserDefaultsRepository.graphCarbs.value = graphCarbs
        }
    }

    @Published var graphOtherTreatments: Bool {
        didSet {
            UserDefaultsRepository.graphOtherTreatments.value = graphOtherTreatments
        }
    }

    @Published var bgUpdateDelay: Int {
        didSet {
            UserDefaultsRepository.bgUpdateDelay.value = bgUpdateDelay
        }
    }

    @Published var debugLogLevel: Bool {
        didSet {
            Storage.shared.debugLogLevel.value = debugLogLevel
        }
    }

    init() {
        downloadTreatments = UserDefaultsRepository.downloadTreatments.value
        downloadPrediction = UserDefaultsRepository.downloadPrediction.value
        graphBasal = UserDefaultsRepository.graphBasal.value
        graphBolus = UserDefaultsRepository.graphBolus.value
        graphCarbs = UserDefaultsRepository.graphCarbs.value
        graphOtherTreatments = UserDefaultsRepository.graphOtherTreatments.value
        bgUpdateDelay = UserDefaultsRepository.bgUpdateDelay.value
        debugLogLevel = Storage.shared.debugLogLevel.value
    }
}
