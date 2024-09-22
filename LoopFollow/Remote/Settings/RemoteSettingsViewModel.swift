//
//  RemoteSettingsViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine
import HealthKit

class RemoteSettingsViewModel: ObservableObject {
    @Published var remoteType: RemoteType
    @Published var user: String
    @Published var deviceToken: String
    @Published var sharedSecret: String
    @Published var productionEnvironment: Bool
    @Published var apnsKey: String
    @Published var teamId: String
    @Published var keyId: String
    @Published var bundleId: String

    @Published var maxBolus: HKQuantity
    @Published var maxCarbs: HKQuantity
    @Published var maxProtein: HKQuantity
    @Published var maxFat: HKQuantity

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.remoteType = storage.remoteType.value
        self.user = storage.user.value
        self.deviceToken = storage.deviceToken.value
        self.sharedSecret = storage.sharedSecret.value
        self.productionEnvironment = storage.productionEnvironment.value
        self.apnsKey = storage.apnsKey.value
        self.teamId = storage.teamId.value
        self.keyId = storage.keyId.value
        self.bundleId = storage.bundleId.value
        self.maxBolus = storage.maxBolus.value
        self.maxCarbs = storage.maxCarbs.value
        self.maxProtein = storage.maxProtein.value
        self.maxFat = storage.maxFat.value

        setupBindings()
    }

    private func setupBindings() {
        $remoteType
            .sink { [weak self] in self?.storage.remoteType.value = $0 }
            .store(in: &cancellables)

        $user
            .sink { [weak self] in self?.storage.user.value = $0 }
            .store(in: &cancellables)

        $deviceToken
            .sink { [weak self] in self?.storage.deviceToken.value = $0 }
            .store(in: &cancellables)

        $sharedSecret
            .sink { [weak self] in self?.storage.sharedSecret.value = $0 }
            .store(in: &cancellables)

        $productionEnvironment
            .sink { [weak self] in self?.storage.productionEnvironment.value = $0 }
            .store(in: &cancellables)

        $apnsKey
            .sink { [weak self] in self?.storage.apnsKey.value = $0 }
            .store(in: &cancellables)

        $teamId
            .sink { [weak self] in self?.storage.teamId.value = $0 }
            .store(in: &cancellables)

        $keyId
            .sink { [weak self] in self?.storage.keyId.value = $0 }
            .store(in: &cancellables)

        $bundleId
            .sink { [weak self] in self?.storage.bundleId.value = $0 }
            .store(in: &cancellables)

        $maxBolus
            .sink { [weak self] in self?.storage.maxBolus.value = $0 }
            .store(in: &cancellables)
        
        $maxCarbs
            .sink { [weak self] in self?.storage.maxCarbs.value = $0 }
            .store(in: &cancellables)

        $maxProtein
            .sink { [weak self] in self?.storage.maxProtein.value = $0 }
            .store(in: &cancellables)

        $maxFat
            .sink { [weak self] in self?.storage.maxFat.value = $0 }
            .store(in: &cancellables)
    }
}
