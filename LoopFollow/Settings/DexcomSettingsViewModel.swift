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
        let serverURL = server == "US"
            ? KnownShareServers.US.rawValue
            : KnownShareServers.NON_US.rawValue
        let client = ShareClient(username: userName, password: password, shareServer: serverURL)

        client.fetchData(1) { [weak self] error, _ in
            DispatchQueue.main.async {
                guard let self, generation == self.verifyGeneration else { return }

                if let error = error {
                    switch error {
                    case .loginError:
                        self.statusKind = .error
                        self.statusMessage = "Username or password not accepted"
                        self.isVerified = false
                        self.loginRejected = true
                    case .httpError:
                        self.statusKind = .error
                        self.statusMessage = "Network error — check your connection"
                        self.isVerified = false
                        self.loginRejected = false
                    default:
                        // Login succeeded but there's no recent reading yet; the
                        // credentials are valid, which is all we're confirming.
                        self.statusKind = .connected
                        self.statusMessage = "Connected"
                        self.isVerified = true
                        self.loginRejected = false
                    }
                } else {
                    self.statusKind = .connected
                    self.statusMessage = "Connected"
                    self.isVerified = true
                    self.loginRejected = false
                }
            }
        }
    }
}
