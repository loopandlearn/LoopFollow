// LoopFollow
// BackgroundRefreshSettingsViewModel.swift

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

        // Touch BLEManager only when switching to a Bluetooth mode (the user is
        // opting in, so the permission prompt belongs here) or when it's already
        // running and needs to be torn down. Switching between non-BLE modes must
        // not initialize Bluetooth — that would prompt without cause.
        if newValue.isBluetooth || BLEManager.isInitialized {
            BLEManager.shared.disconnect()
        }
    }
}
