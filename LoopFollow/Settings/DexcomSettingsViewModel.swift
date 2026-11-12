// LoopFollow
// DexcomSettingsViewModel.swift

import Combine
import Foundation
import ShareClient

class DexcomSettingsViewModel: ObservableObject {
    enum ConnectionStatusKind {
        case idle
        case checking
        case connected
        case error
    }

    /// Whether this is a fresh setup (credentials were empty when view appeared)
    private(set) var isFreshSetup: Bool = false

    @Published var userName: String = Storage.shared.shareUserName.value {
        willSet {
            if newValue != userName {
                Storage.shared.shareUserName.value = newValue
                scheduleVerification()
            }
        }
    }

    @Published var password: String = Storage.shared.sharePassword.value {
        willSet {
            if newValue != password {
                Storage.shared.sharePassword.value = newValue
                scheduleVerification()
            }
        }
    }

    @Published var server: String = Storage.shared.shareServer.value {
        willSet {
            if newValue != server {
                Storage.shared.shareServer.value = newValue
                scheduleVerification()
            }
        }
    }

    /// Whether credentials are filled in
    var hasCredentials: Bool {
        !userName.isEmpty && !password.isEmpty
    }

    // MARK: - Verification

    @Published var statusKind: ConnectionStatusKind = .idle
    @Published var statusMessage: String = "Enter your username and password"

    /// True when a real Dexcom Share login succeeded.
    @Published private(set) var isVerified: Bool = false

    /// The credentials were explicitly rejected by Dexcom (as opposed to a network
    /// failure we can't draw a conclusion from).
    private(set) var loginRejected: Bool = false

    /// Can move on: verified, or the only problem is that we couldn't reach Dexcom
    /// (so we don't trap a user on a flaky network). A rejected login always blocks.
    var canVerifyProceed: Bool {
        hasCredentials && statusKind != .checking && !loginRejected
    }

    private var verifyGeneration = 0
    private var cancellables = Set<AnyCancellable>()
    private let verifySubject = PassthroughSubject<Void, Never>()

    init() {
        isFreshSetup = Storage.shared.shareUserName.value.isEmpty

        verifySubject
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.verify() }
            .store(in: &cancellables)

        scheduleVerification()

        // A change made elsewhere while the screen is open, such as LF Hub putting its
        // data source back, shows in the fields.
        Storage.shared.shareUserName.$value
            .merge(with: Storage.shared.sharePassword.$value, Storage.shared.shareServer.$value)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.followStorage() }
            .store(in: &cancellables)
    }

    private func followStorage() {
        let storage = Storage.shared
        if storage.shareUserName.value != userName { userName = storage.shareUserName.value }
        if storage.sharePassword.value != password { password = storage.sharePassword.value }
        if storage.shareServer.value != server { server = storage.shareServer.value }
    }

    /// Resets status to "checking" and queues a debounced verification.
    private func scheduleVerification() {
        verifyGeneration += 1
        loginRejected = false
        isVerified = false
        if hasCredentials {
            statusKind = .checking
            statusMessage = "Checking your account…"
            verifySubject.send()
        } else {
            statusKind = .idle
            statusMessage = "Enter your username and password"
        }
    }

    private func verify() {
        guard hasCredentials else { return }

        let generation = verifyGeneration
        Self.checkLogin(userName: userName, password: password, server: server) { [weak self] result in
            guard let self, generation == self.verifyGeneration else { return }
            switch result {
            case .rejected:
                self.statusKind = .error
                self.statusMessage = "Username or password not accepted"
                self.isVerified = false
                self.loginRejected = true
            case .unreachable:
                self.statusKind = .error
                self.statusMessage = "Network error — check your connection"
                self.isVerified = false
                self.loginRejected = false
            case .accepted:
                self.statusKind = .connected
                self.statusMessage = "Connected"
                self.isVerified = true
                self.loginRejected = false
            }
        }
    }

    enum LoginCheck {
        case accepted
        case rejected
        case unreachable
    }

    /// Logs in to Dexcom Share with the credentials; `completion` runs on the main queue.
    static func checkLogin(userName: String, password: String, server: String,
                           completion: @escaping (LoginCheck) -> Void)
    {
        let serverURL = server == "US"
            ? KnownShareServers.US.rawValue
            : KnownShareServers.NON_US.rawValue
        let client = ShareClient(username: userName, password: password, shareServer: serverURL)

        client.fetchData(1) { error, _ in
            let result: LoginCheck
            switch error {
            case .loginError: result = .rejected
            case .httpError: result = .unreachable
            // Login succeeded but there's no recent reading yet; the
            // credentials are valid, which is all we're confirming.
            default: result = .accepted
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
