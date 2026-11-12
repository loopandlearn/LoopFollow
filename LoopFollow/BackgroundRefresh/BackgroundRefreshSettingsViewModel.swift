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
                guard let self = self, newValue != self.storage.backgroundRefreshType.value else { return }
                Self.change(to: newValue)
            }
            .store(in: &cancellables)

        // A change made elsewhere (leaving Hub mode on disconnect) shows here too.
        storage.backgroundRefreshType.$value
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                guard let self = self, self.backgroundRefreshType != value else { return }
                self.backgroundRefreshType = value
            }
            .store(in: &cancellables)
    }

    /// Switches the Background Refresh mode: the one path for every change, from
    /// this screen or from LF Hub. Entering or leaving Hub mode answers the task that
    /// brings the hub up to date.
    @discardableResult
    static func change(to newValue: BackgroundRefreshType) -> Task<Void, Never>? {
        let storage = Storage.shared
        LogManager.shared.log(category: .general, message: "Background refresh type changed to: \(newValue.rawValue)")

        // Touch BLEManager only when switching to a Bluetooth mode (the user is
        // opting in, so the permission prompt belongs here) or when it's already
        // running and needs to be torn down. Switching between non-BLE modes must
        // not initialize Bluetooth — that would prompt without cause.
        if newValue.isBluetooth || BLEManager.isInitialized {
            BLEManager.shared.disconnect()
        }

        // Entering or leaving Hub mode changes what the hub drives. Hub alarms
        // ring as system alarms only with AlarmKit allowed. The app keeps alarming
        // itself until the hub confirms. Storage still holds the mode being left.
        let hubModeChanges = newValue == .hub || storage.backgroundRefreshType.value == .hub
        if hubModeChanges, HubClient.shared.isConnected {
            HubClient.shared.hubSettingsPending.value = true
        }
        if newValue == .hub { HubClient.shared.hubConfirmed.value = false }

        // Persist the change
        storage.backgroundRefreshType.value = newValue

        MainViewController.shared?.backgroundModeChanged()
        if storage.backgroundRefreshType.value != .hub { HubBundle.shared.stopListening() }
        guard hubModeChanges else { return nil }
        return Task {
            #if !targetEnvironment(macCatalyst)
                if newValue == .hub, #available(iOS 26, *) { _ = await HubAlarmKit.requestAuthorization() }
            #endif
            // In the foreground the sync starts the hub's long poll and its watchdog
            // checks, as coming to the foreground does.
            await HubClient.shared.sync()
            if newValue == .hub { await HubWatchdog.check() }
        }
    }
}
