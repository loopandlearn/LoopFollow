// LoopFollow
// RemoteSettingsViewModel.swift
// Created by Jonas Björkert.

import Combine
import Foundation
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
    @Published var isTrioDevice: Bool = (Storage.shared.device.value == "Trio")

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        remoteType = storage.remoteType.value
        user = storage.user.value
        sharedSecret = storage.sharedSecret.value
        apnsKey = storage.apnsKey.value
        keyId = storage.keyId.value
        maxBolus = storage.maxBolus.value
        maxCarbs = storage.maxCarbs.value
        maxProtein = storage.maxProtein.value
        maxFat = storage.maxFat.value
        mealWithBolus = storage.mealWithBolus.value
        mealWithFatProtein = storage.mealWithFatProtein.value

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

        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isTrioDevice = (newValue == "Trio")
            }
            .store(in: &cancellables)
    }
}
