// LoopFollow
// BackgroundRefreshSettingsViewModel.swift
// Created by Jonas Björkert on 2025-01-13.

import Combine
import Foundation

class BackgroundRefreshSettingsViewModel: ObservableObject {
    @Published var backgroundRefreshType: BackgroundRefreshType

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    private var isInitialSetup = true // Tracks whether the value is being set initially

    init() {
        backgroundRefreshType = storage.backgroundRefreshType.value
        setupBindings()
    }

    private func setupBindings() {
        $backgroundRefreshType
            .dropFirst() // Ignore the initial emission during setup
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.handleBackgroundRefreshTypeChange(newValue)

                // Persist the change
                self.storage.backgroundRefreshType.value = newValue
            }
            .store(in: &cancellables)
    }

    private func handleBackgroundRefreshTypeChange(_ newValue: BackgroundRefreshType) {
        LogManager.shared.log(category: .general, message: "Background refresh type changed to: \(newValue.rawValue)")

        BLEManager.shared.disconnect()
    }
}
