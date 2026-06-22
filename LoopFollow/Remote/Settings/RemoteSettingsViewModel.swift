// LoopFollow
// RemoteSettingsViewModel.swift

import Combine
import Foundation
import HealthKit

class RemoteSettingsViewModel: ObservableObject {
    @Published var remoteType: RemoteType
    @Published var user: String
    @Published var sharedSecret: String
    @Published var remoteApnsKey: String
    @Published var remoteKeyId: String

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
    @Published var productionEnvironment: Bool
    @Published var isShowingLoopAPNSScanner: Bool = false
    @Published var loopAPNSErrorMessage: String?

    // MARK: - URL/Token Validation Properties

    @Published var pendingSettings: RemoteCommandSettings?
    @Published var showURLTokenValidation: Bool = false
    @Published var validationMessage: String = ""
    @Published var shouldPromptForURL: Bool = false
    @Published var shouldPromptForToken: Bool = false

    // MARK: - Diagnostics

    @Published var diagnostics = RemoteDiagnostics()
    private let diagnosticsHistoryCap = 1000
    private let futureStartDateTolerance: TimeInterval = 60

    let loopFollowTeamId: String = BuildDetails.default.teamID ?? "Unknown"

    /// Determines if the target app's Team ID is different from this app's build Team ID.
    var areTeamIdsDifferent: Bool {
        // Get LoopFollow's own Team ID from the build details.
        guard let loopFollowTeamID = BuildDetails.default.teamID, !loopFollowTeamID.isEmpty, loopFollowTeamID != "Unknown" else {
            return false
        }

        // The property `loopDeveloperTeamId` holds the value from `Storage.shared.teamId`
        let targetTeamId = loopDeveloperTeamId

        // Determine if a comparison is needed and perform it.
        switch remoteType {
        case .trc, .loopAPNS:
            guard !targetTeamId.isEmpty else {
                return false
            }
            return loopFollowTeamID != targetTeamId

        case .none:
            return false
        }
    }

    // MARK: - Computed property for Loop APNS Setup validation

    var loopAPNSSetup: Bool {
        let hasCredentials: Bool
        if areTeamIdsDifferent {
            hasCredentials = !remoteKeyId.isEmpty && !remoteApnsKey.isEmpty
        } else {
            hasCredentials = !Storage.shared.lfKeyId.value.isEmpty && !Storage.shared.lfApnsKey.value.isEmpty
        }
        return hasCredentials &&
            !loopDeveloperTeamId.isEmpty &&
            !loopAPNSQrCodeURL.isEmpty &&
            !Storage.shared.deviceToken.value.isEmpty &&
            !Storage.shared.bundleId.value.isEmpty
    }

    private var storage = Storage.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize published properties from storage
        remoteType = storage.remoteType.value
        user = storage.user.value
        sharedSecret = storage.sharedSecret.value
        remoteApnsKey = storage.remoteApnsKey.value
        remoteKeyId = storage.remoteKeyId.value
        maxBolus = storage.maxBolus.value
        maxCarbs = storage.maxCarbs.value
        maxProtein = storage.maxProtein.value
        maxFat = storage.maxFat.value
        mealWithBolus = storage.mealWithBolus.value
        mealWithFatProtein = storage.mealWithFatProtein.value

        loopDeveloperTeamId = storage.teamId.value ?? ""
        loopAPNSQrCodeURL = storage.loopAPNSQrCodeURL.value
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

        $remoteApnsKey
            .dropFirst()
            .sink { [weak self] newValue in
                let apnsService = LoopAPNSService()
                let fixedKey = apnsService.validateAndFixAPNSKey(newValue)
                self?.storage.remoteApnsKey.value = fixedKey
            }
            .store(in: &cancellables)

        $remoteKeyId
            .dropFirst()
            .sink { [weak self] in self?.storage.remoteKeyId.value = $0 }
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

        $productionEnvironment
            .dropFirst()
            .sink { [weak self] in self?.storage.productionEnvironment.value = $0 }
            .store(in: &cancellables)
    }

    func handleLoopAPNSQRCodeScanResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case let .success(code):
                self.loopAPNSQrCodeURL = code
                // Set device type and remote type for Loop APNS
                Storage.shared.device.value = "Loop"
                Storage.shared.remoteType.value = .loopAPNS
                // Update view model properties
                self.remoteType = .loopAPNS
                self.isLoopDevice = true
                self.isTrioDevice = false
                LogManager.shared.log(category: .apns, message: "Loop APNS QR code scanned: \(LogRedactor.fingerprint(code))")
            case let .failure(error):
                self.loopAPNSErrorMessage = "Scanning failed: \(error.localizedDescription)"
            }
            self.isShowingLoopAPNSScanner = false
        }
    }

    // MARK: - Public Methods for View Access

    /// Updates the view model properties from storage (accessible from view)
    func updateViewModelFromStorage() {
        let storage = Storage.shared
        remoteType = storage.remoteType.value
        user = storage.user.value
        sharedSecret = storage.sharedSecret.value
        remoteApnsKey = storage.remoteApnsKey.value
        remoteKeyId = storage.remoteKeyId.value
        maxBolus = storage.maxBolus.value
        maxCarbs = storage.maxCarbs.value
        maxProtein = storage.maxProtein.value
        maxFat = storage.maxFat.value
        mealWithBolus = storage.mealWithBolus.value
        mealWithFatProtein = storage.mealWithFatProtein.value
        loopDeveloperTeamId = storage.teamId.value ?? ""
        loopAPNSQrCodeURL = storage.loopAPNSQrCodeURL.value
        productionEnvironment = storage.productionEnvironment.value

        // Update device-related properties
        isTrioDevice = (storage.device.value == "Trio")
        isLoopDevice = (storage.device.value == "Loop")
    }

    // MARK: - Diagnostics

    func runDiagnostics() {
        diagnostics = RemoteDiagnostics(status: .running)

        guard !storage.url.value.isEmpty else {
            diagnostics = RemoteDiagnostics(status: .ok)
            return
        }

        let parameters: [String: String] = [
            "count": "\(diagnosticsHistoryCap)",
        ]
        NightscoutUtils.executeRequest(
            eventType: .profile,
            parameters: parameters
        ) { [weak self] (result: Result<[NSProfile], Error>) in
            guard let self = self else { return }
            switch result {
            case let .success(history):
                let evaluated = self.evaluateDiagnostics(history: history)
                DispatchQueue.main.async {
                    self.diagnostics = evaluated
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "Remote diagnostics evaluated: records=\(history.count) bundleMismatch=\(evaluated.bundleMismatch != nil) bouncingTokens=\(evaluated.bouncingTokens != nil) futureStartDate=\(evaluated.futureStartDate != nil)"
                    )
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    self.diagnostics = RemoteDiagnostics(status: .failed(error.localizedDescription))
                }
            }
        }
    }

    private func evaluateDiagnostics(history: [NSProfile]) -> RemoteDiagnostics {
        var result = RemoteDiagnostics(status: .ok)
        let device = storage.device.value

        if let current = history.first, !device.isEmpty {
            let topLevel = current.bundleIdentifier?.trimmingCharacters(in: .whitespaces) ?? ""
            let nested = current.loopSettings?.bundleIdentifier?.trimmingCharacters(in: .whitespaces) ?? ""

            if device == "Loop", nested.isEmpty, !topLevel.isEmpty {
                result.bundleMismatch = .init(expectedDevice: "Loop", observedBundleId: topLevel)
            } else if device == "Trio", topLevel.isEmpty, !nested.isEmpty {
                result.bundleMismatch = .init(expectedDevice: "Trio", observedBundleId: nested)
            }
        }

        let chronological = history.sorted { lhs, rhs in
            profileTimestamp(lhs) < profileTimestamp(rhs)
        }
        struct CompressedEntry {
            let token: String
            let when: Date
            let bundle: String?
        }
        var compressed: [CompressedEntry] = []
        for record in chronological {
            guard let token = record.deviceToken ?? record.loopSettings?.deviceToken,
                  !token.isEmpty else { continue }
            if compressed.last?.token != token {
                compressed.append(
                    CompressedEntry(
                        token: token,
                        when: profileTimestamp(record),
                        bundle: record.bundleIdentifier ?? record.loopSettings?.bundleIdentifier
                    )
                )
            }
        }
        let distinctTokens = Set(compressed.map { $0.token })
        if compressed.count > distinctTokens.count {
            var shifts: [RemoteDiagnostics.TokenShift] = []
            for pair in zip(compressed, compressed.dropFirst()) {
                shifts.append(
                    RemoteDiagnostics.TokenShift(
                        when: pair.1.when,
                        fromToken: pair.0.token,
                        toToken: pair.1.token,
                        bundleIdentifier: pair.1.bundle
                    )
                )
            }
            result.bouncingTokens = .init(
                distinctCount: distinctTokens.count,
                recordsScanned: history.count,
                shifts: shifts
            )
        }

        let dates = history.compactMap { $0.startDate.flatMap(NightscoutUtils.parseDate) }
        if let maxDate = dates.max(), maxDate > Date().addingTimeInterval(futureStartDateTolerance) {
            result.futureStartDate = .init(startDate: maxDate)
        }

        return result
    }

    private func profileTimestamp(_ profile: NSProfile) -> Date {
        if let s = profile.startDate, let d = NightscoutUtils.parseDate(s) { return d }
        if let s = profile.createdAt, let d = NightscoutUtils.parseDate(s) { return d }
        return .distantPast
    }
}
