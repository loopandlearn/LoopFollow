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
    @Published var loopAPNSSetup: Bool
    @Published var productionEnvironment: Bool
    @Published var isShowingLoopAPNSScanner: Bool = false
    @Published var loopAPNSErrorMessage: String?
    @Published var isRefreshingDeviceToken: Bool = false

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
        loopAPNSSetup = storage.loopAPNSSetup.value
        productionEnvironment = storage.productionEnvironment.value

        setupBindings()

        // Trigger initial validation
        validateLoopAPNSSetup()
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

        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isTrioDevice = (newValue == "Trio")
                self?.isLoopDevice = (newValue == "Loop")
            }
            .store(in: &cancellables)

        // Loop APNS setup bindings
        $keyId
            .dropFirst()
            .sink { [weak self] in self?.storage.keyId.value = $0 }
            .store(in: &cancellables)

        $apnsKey
            .dropFirst()
            .sink { [weak self] newValue in
                // Log APNS key changes for debugging
                LogManager.shared.log(category: .apns, message: "APNS Key changed - Length: \(newValue.count)")
                LogManager.shared.log(category: .apns, message: "APNS Key contains line breaks: \(newValue.contains("\n"))")
                LogManager.shared.log(category: .apns, message: "APNS Key contains BEGIN header: \(newValue.contains("-----BEGIN PRIVATE KEY-----"))")
                LogManager.shared.log(category: .apns, message: "APNS Key contains END header: \(newValue.contains("-----END PRIVATE KEY-----"))")

                // Validate and fix the APNS key format using the service
                let apnsService = LoopAPNSService()
                let fixedKey = apnsService.validateAndFixAPNSKey(newValue)

                self?.storage.apnsKey.value = fixedKey
            }
            .store(in: &cancellables)

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

        // Sync loopAPNSSetup with storage
        Storage.shared.loopAPNSSetup.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.loopAPNSSetup = newValue
            }
            .store(in: &cancellables)

        $productionEnvironment
            .dropFirst()
            .sink { [weak self] in self?.storage.productionEnvironment.value = $0 }
            .store(in: &cancellables)

        // Auto-validate Loop APNS setup when key ID, APNS key, or QR code changes
        Publishers.CombineLatest3($keyId, $apnsKey, $loopAPNSQrCodeURL)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.validateLoopAPNSSetup()
            }
            .store(in: &cancellables)

        // Auto-validate when device token or bundle identifier changes
        Publishers.CombineLatest($loopAPNSDeviceToken, $loopAPNSBundleIdentifier)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.validateFullLoopAPNSSetup()
            }
            .store(in: &cancellables)

        // Auto-validate when production environment changes
        $productionEnvironment
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.validateFullLoopAPNSSetup()
            }
            .store(in: &cancellables)

        $loopDeveloperTeamId
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.validateLoopAPNSSetup()
            }
            .store(in: &cancellables)
    }

    // MARK: - Loop APNS Setup Methods

    /// Validates the Loop APNS setup by checking all required fields
    /// - Returns: True if setup is valid, false otherwise
    func validateLoopAPNSSetup() {
        let hasKeyId = !keyId.isEmpty
        let hasAPNSKey = !apnsKey.isEmpty
        let hasQrCode = !loopAPNSQrCodeURL.isEmpty
        let hasDeviceToken = !loopAPNSDeviceToken.isEmpty
        let hasBundleIdentifier = !loopAPNSBundleIdentifier.isEmpty

        // For initial setup, we don't require device token and bundle identifier
        // These will be fetched when the user clicks "Refresh Device Token"
        let hasBasicSetup = hasKeyId && hasAPNSKey && hasQrCode

        // For full validation (after device token is fetched), check everything
        let hasFullSetup = hasBasicSetup && hasDeviceToken && hasBundleIdentifier

        let oldSetup = loopAPNSSetup
        storage.loopAPNSSetup.value = hasFullSetup

        // Log validation results for debugging
        LogManager.shared.log(category: .apns, message: "Loop APNS setup validation - Key ID: \(hasKeyId), APNS Key: \(hasAPNSKey), QR Code: \(hasQrCode), Device Token: \(hasDeviceToken), Bundle ID: \(hasBundleIdentifier), Valid: \(hasFullSetup)")

        // Post notification if setup status changed
        if oldSetup != hasFullSetup {
            NotificationCenter.default.post(name: NSNotification.Name("LoopAPNSSetupChanged"), object: nil)
        }
    }

    /// Validates the full Loop APNS setup including device token and bundle identifier
    /// - Returns: True if full setup is valid, false otherwise
    func validateFullLoopAPNSSetup() {
        let hasKeyId = !keyId.isEmpty
        let hasAPNSKey = !apnsKey.isEmpty
        let hasQrCode = !loopAPNSQrCodeURL.isEmpty
        let hasDeviceToken = !loopAPNSDeviceToken.isEmpty
        let hasBundleIdentifier = !loopAPNSBundleIdentifier.isEmpty

        let hasFullSetup = hasKeyId && hasAPNSKey && hasQrCode && hasDeviceToken && hasBundleIdentifier

        let oldSetup = loopAPNSSetup
        storage.loopAPNSSetup.value = hasFullSetup

        // Log validation results for debugging
        LogManager.shared.log(category: .apns, message: "Full Loop APNS setup validation - Key ID: \(hasKeyId), APNS Key: \(hasAPNSKey), QR Code: \(hasQrCode), Device Token: \(hasDeviceToken), Bundle ID: \(hasBundleIdentifier), Valid: \(hasFullSetup)")

        // Post notification if setup status changed
        if oldSetup != hasFullSetup {
            NotificationCenter.default.post(name: NSNotification.Name("LoopAPNSSetupChanged"), object: nil)
        }
    }

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
                // Trigger validation immediately after updating values
                self.validateFullLoopAPNSSetup()
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
                        LogManager.shared.log(category: .apns, message: "Device token from profile: \(profileData.deviceToken ?? "nil")")
                        LogManager.shared.log(category: .apns, message: "Bundle identifier from profile: \(profileData.bundleIdentifier ?? "nil")")

                        if let loopSettings = profileData.loopSettings {
                            LogManager.shared.log(category: .apns, message: "Loop settings device token: \(loopSettings.deviceToken ?? "nil")")
                            LogManager.shared.log(category: .apns, message: "Loop settings bundle identifier: \(loopSettings.bundleIdentifier ?? "nil")")
                        }

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

                        // Log the stored values after processing
                        LogManager.shared.log(category: .apns, message: "Stored device token: \(self.storage.loopAPNSDeviceToken.value)")
                        LogManager.shared.log(category: .apns, message: "Stored bundle ID: \(self.storage.loopAPNSBundleIdentifier.value)")

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
                // Trigger validation after QR code is scanned
                self.validateLoopAPNSSetup()
            case let .failure(error):
                self.loopAPNSErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingLoopAPNSScanner = false
        }
    }

    /// Forces validation of Loop APNS setup
    func forceValidateLoopAPNSSetup() {
        validateLoopAPNSSetup()
    }

    /// Forces validation of full Loop APNS setup including device token
    func forceValidateFullLoopAPNSSetup() {
        validateFullLoopAPNSSetup()
    }
}
