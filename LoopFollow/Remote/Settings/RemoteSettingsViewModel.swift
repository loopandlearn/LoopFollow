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

    // MARK: - Loop Remote Setup Properties

    @Published var loopApiSecret: String
    @Published var loopQrCodeURL: String
    @Published var loopRemoteSetup: Bool
    @Published var isShowingScanner: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init(initialRemoteType: RemoteType? = nil) {
        remoteType = initialRemoteType ?? storage.remoteType.value
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

        // Loop remote setup properties
        loopApiSecret = storage.loopApiSecret.value
        loopQrCodeURL = storage.loopQrCodeURL.value
        loopRemoteSetup = storage.loopRemoteSetup.value

        setupBindings()

        // Validate initial state
        validateLoopRemoteSetup(apiSecret: loopApiSecret, qrCodeURL: loopQrCodeURL)
    }

    private func setupBindings() {
        $remoteType
            .dropFirst()
            .sink { [weak self] in self?.storage.remoteType.value = $0 }
            .store(in: &cancellables)

        $user
            .dropFirst()
            .sink { [weak self] in self?.storage.user.value = $0 }
            .store(in: &cancellables)

        $sharedSecret
            .dropFirst()
            .sink { [weak self] in self?.storage.sharedSecret.value = $0 }
            .store(in: &cancellables)

        $apnsKey
            .dropFirst()
            .sink { [weak self] in self?.storage.apnsKey.value = $0 }
            .store(in: &cancellables)

        $keyId
            .dropFirst()
            .sink { [weak self] in self?.storage.keyId.value = $0 }
            .store(in: &cancellables)

        $maxBolus
            .dropFirst()
            .sink { [weak self] in self?.storage.maxBolus.value = $0 }
            .store(in: &cancellables)

        $maxCarbs
            .dropFirst()
            .sink { [weak self] in self?.storage.maxCarbs.value = $0 }
            .store(in: &cancellables)

        $maxProtein
            .dropFirst()
            .sink { [weak self] in self?.storage.maxProtein.value = $0 }
            .store(in: &cancellables)

        $maxFat
            .dropFirst()
            .sink { [weak self] in self?.storage.maxFat.value = $0 }
            .store(in: &cancellables)

        $mealWithBolus
            .dropFirst()
            .sink { [weak self] in self?.storage.mealWithBolus.value = $0 }
            .store(in: &cancellables)

        $mealWithFatProtein
            .dropFirst()
            .sink { [weak self] in self?.storage.mealWithFatProtein.value = $0 }
            .store(in: &cancellables)

        // Loop remote setup bindings
        $loopApiSecret
            .dropFirst()
            .sink { [weak self] in self?.storage.loopApiSecret.value = $0 }
            .store(in: &cancellables)

        $loopQrCodeURL
            .dropFirst()
            .sink { [weak self] in self?.storage.loopQrCodeURL.value = $0 }
            .store(in: &cancellables)

        $loopRemoteSetup
            .dropFirst()
            .sink { [weak self] in self?.storage.loopRemoteSetup.value = $0 }
            .store(in: &cancellables)

        // Auto-validate Loop remote setup when API secret or QR code changes
        Publishers.CombineLatest($loopApiSecret, $loopQrCodeURL)
            .dropFirst()
            .sink { [weak self] apiSecret, qrCodeURL in
                self?.validateLoopRemoteSetup(apiSecret: apiSecret, qrCodeURL: qrCodeURL)
            }
            .store(in: &cancellables)

        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isTrioDevice = (newValue == "Trio")
            }
            .store(in: &cancellables)
    }

    // MARK: - Loop Remote Setup Methods

    private func validateLoopRemoteSetup(apiSecret: String, qrCodeURL: String) {
        // Check if we have both API secret and a valid TOTP QR code
        let hasApiSecret = !apiSecret.isEmpty
        let hasValidTOTP = !qrCodeURL.isEmpty && TOTPGenerator.extractOTPFromURL(qrCodeURL) != nil

        // Auto-set loopRemoteSetup to true if both conditions are met
        if hasApiSecret && hasValidTOTP {
            loopRemoteSetup = true
        } else {
            loopRemoteSetup = false
        }
    }

    func saveLoopRemoteSetup() {
        isLoading = true
        errorMessage = nil

        // Validate the setup
        guard !storage.url.value.isEmpty else {
            errorMessage = "Please configure your Nightscout URL in the main settings"
            isLoading = false
            return
        }

        guard !loopApiSecret.isEmpty else {
            errorMessage = "Please configure your API Secret"
            isLoading = false
            return
        }

        guard !loopQrCodeURL.isEmpty else {
            errorMessage = "Please scan the QR code from your Loop app"
            isLoading = false
            return
        }

        // Mark setup as complete (values are already saved via bindings)
        loopRemoteSetup = true

        isLoading = false
    }

    func handleQRCodeScanResult(_ result: Result<String, Error>) {
        switch result {
        case let .success(code):
            loopQrCodeURL = code
        case let .failure(error):
            errorMessage = "Scanning failed: \(error.localizedDescription)"
        }
        isShowingScanner = false
    }
}
