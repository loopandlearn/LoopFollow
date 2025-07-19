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
    @Published var isLoopDevice: Bool = (Storage.shared.device.value == "Loop")

    // MARK: - Loop APNS Setup Properties

    @Published var loopDeveloperTeamId: String
    @Published var loopAPNSQrCodeURL: String
    @Published var loopAPNSDeviceToken: String
    @Published var loopAPNSBundleIdentifier: String
    @Published var productionEnvironment: Bool
    @Published var isShowingLoopAPNSScanner: Bool = false
    @Published var loopAPNSErrorMessage: String?
    @Published var isRefreshingDeviceToken: Bool = false

    // MARK: - Computed property for Loop APNS Setup validation

    var loopAPNSSetup: Bool {
        !keyId.isEmpty &&
            !apnsKey.isEmpty &&
            !loopAPNSQrCodeURL.isEmpty &&
            !loopAPNSDeviceToken.isEmpty &&
            !loopAPNSBundleIdentifier.isEmpty
    }

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize published properties from storage
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

        loopDeveloperTeamId = storage.teamId.value ?? ""
        loopAPNSQrCodeURL = storage.loopAPNSQrCodeURL.value
        loopAPNSDeviceToken = storage.loopAPNSDeviceToken.value
        loopAPNSBundleIdentifier = storage.loopAPNSBundleIdentifier.value
        productionEnvironment = storage.productionEnvironment.value

        setupBindings()
    }

    private func setupBindings() {
        // Basic property bindings
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
            .sink { [weak self] newValue in
                // Validate and fix the APNS key format using the service
                let apnsService = LoopAPNSService()
                let fixedKey = apnsService.validateAndFixAPNSKey(newValue)
                self?.storage.apnsKey.value = fixedKey
            }
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

        // Device type monitoring
        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isTrioDevice = (newValue == "Trio")
                self?.isLoopDevice = (newValue == "Loop")
            }
            .store(in: &cancellables)

        // Loop APNS bindings
        $loopDeveloperTeamId
            .dropFirst()
            .sink { [weak self] in self?.storage.teamId.value = $0 }
            .store(in: &cancellables)

        $loopAPNSQrCodeURL
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSQrCodeURL.value = $0 }
            .store(in: &cancellables)

        $loopAPNSDeviceToken
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSDeviceToken.value = $0 }
            .store(in: &cancellables)

        $loopAPNSBundleIdentifier
            .dropFirst()
            .sink { [weak self] in self?.storage.loopAPNSBundleIdentifier.value = $0 }
            .store(in: &cancellables)

        $productionEnvironment
            .dropFirst()
            .sink { [weak self] in self?.storage.productionEnvironment.value = $0 }
            .store(in: &cancellables)
    }

    // MARK: - Loop APNS Setup Methods

    func refreshDeviceToken() async {
        await MainActor.run {
            isRefreshingDeviceToken = true
            loopAPNSErrorMessage = nil
        }

        // Use the regular Nightscout profile endpoint instead of the Loop APNS service
        let success = await fetchDeviceTokenFromNightscoutProfile()

        await MainActor.run {
            self.isRefreshingDeviceToken = false
            if success {
                self.loopAPNSDeviceToken = self.storage.loopAPNSDeviceToken.value
                self.loopAPNSBundleIdentifier = self.storage.loopAPNSBundleIdentifier.value
            } else {
                self.loopAPNSErrorMessage = "Failed to refresh device token. Check your Nightscout URL and token."
            }
        }
    }

    private func fetchDeviceTokenFromNightscoutProfile() async -> Bool {
        // Check if Nightscout is configured
        guard !Storage.shared.url.value.isEmpty else {
            LogManager.shared.log(category: .apns, message: "Nightscout URL not configured")
            return false
        }

        guard !Storage.shared.token.value.isEmpty else {
            LogManager.shared.log(category: .apns, message: "Nightscout token not configured")
            return false
        }

        // Fetch profile from Nightscout using the regular profile endpoint
        return await withCheckedContinuation { continuation in
            NightscoutUtils.executeRequest(eventType: .profile, parameters: [:]) { (result: Result<NSProfile, Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case let .success(profileData):
                        // Log the profile data for debugging
                        LogManager.shared.log(category: .apns, message: "Profile fetched successfully for device token")

                        // Update profile data which includes device token and bundle identifier
                        ProfileManager.shared.loadProfile(from: profileData)

                        // Store the device token and bundle identifier in the Loop APNS storage
                        if let deviceToken = profileData.deviceToken, !deviceToken.isEmpty {
                            self.storage.loopAPNSDeviceToken.value = deviceToken
                        } else if let loopSettings = profileData.loopSettings, let deviceToken = loopSettings.deviceToken, !deviceToken.isEmpty {
                            self.storage.loopAPNSDeviceToken.value = deviceToken
                        }

                        if let bundleIdentifier = profileData.bundleIdentifier, !bundleIdentifier.isEmpty {
                            self.storage.loopAPNSBundleIdentifier.value = bundleIdentifier
                        } else if let loopSettings = profileData.loopSettings, let bundleIdentifier = loopSettings.bundleIdentifier, !bundleIdentifier.isEmpty {
                            self.storage.loopAPNSBundleIdentifier.value = bundleIdentifier
                        }

                        // Log successful configuration
                        LogManager.shared.log(category: .apns, message: "Successfully configured device tokens from Nightscout profile")

                        continuation.resume(returning: true)

                    case let .failure(error):
                        LogManager.shared.log(category: .apns, message: "Failed to fetch profile for device token configuration: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    func handleLoopAPNSQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(code):
                self.loopAPNSQrCodeURL = code
                LogManager.shared.log(category: .apns, message: "Loop APNS QR code scanned: \(code)")
            case let .failure(error):
                self.loopAPNSErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingLoopAPNSScanner = false
        }
    }
}
