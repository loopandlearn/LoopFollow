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
    @Published var sharedSecret: String
    @Published var apnsKey: String
    @Published var keyId: String

    @Published var maxBolus: HKQuantity
    @Published var maxCarbs: HKQuantity
    @Published var maxProtein: HKQuantity
    @Published var maxFat: HKQuantity
    @Published var mealWithBolus: Bool
    @Published var mealWithFatProtein: Bool

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.remoteType = storage.remoteType.value
        self.user = storage.user.value
        self.sharedSecret = storage.sharedSecret.value
        self.apnsKey = storage.apnsKey.value
        self.keyId = storage.keyId.value
        self.maxBolus = storage.maxBolus.value
        self.maxCarbs = storage.maxCarbs.value
        self.maxProtein = storage.maxProtein.value
        self.maxFat = storage.maxFat.value
        self.mealWithBolus = storage.mealWithBolus.value
        self.mealWithFatProtein = storage.mealWithFatProtein.value

        setupBindings()
    }

    private func setupBindings() {
        $remoteType
            .sink { [weak self] in self?.storage.remoteType.value = $0 }
            .store(in: &cancellables)

        $user
            .sink { [weak self] in self?.storage.user.value = $0 }
            .store(in: &cancellables)

        $sharedSecret
            .sink { [weak self] in self?.storage.sharedSecret.value = $0 }
            .store(in: &cancellables)

        $apnsKey
            .sink { [weak self] in self?.storage.apnsKey.value = $0 }
            .store(in: &cancellables)

        $keyId
            .sink { [weak self] in self?.storage.keyId.value = $0 }
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

        $mealWithBolus
            .sink { [weak self] in self?.storage.mealWithBolus.value = $0 }
            .store(in: &cancellables)

        $mealWithFatProtein
            .sink { [weak self] in self?.storage.mealWithFatProtein.value = $0 }
            .store(in: &cancellables)
    }
}
