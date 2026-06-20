// LoopFollow
// NightscoutSettingsViewModel.swift

import Combine
import Foundation
import SwiftUI

class NightscoutSettingsViewModel: ObservableObject {
    private var initialURL: String
    private var initialToken: String

    /// Whether the Nightscout connection is successfully verified
    @Published var isConnected: Bool = false

    /// Whether this is a fresh setup (URL was empty when view appeared)
    private(set) var isFreshSetup: Bool = false

    @Published var nightscoutURL: String = Storage.shared.url.value {
        willSet {
            if newValue != nightscoutURL {
                Storage.shared.url.value = newValue
                triggerCheckStatus()
            }
        }
    }

    @Published var nightscoutToken: String = Storage.shared.token.value {
        willSet {
            if newValue != nightscoutToken {
                Storage.shared.token.value = newValue
                triggerCheckStatus()
            }
        }
    }

    @Published var nightscoutStatus: String = "Checking..."

    /// The most recent verification error, kept so the onboarding address page can
    /// tell "reachable Nightscout that needs a token" apart from "can't reach it".
    @Published var lastError: NightscoutUtils.NightscoutError?

    /// True when the most recent error means the site is a reachable Nightscout
    /// that simply needs (a different) token.
    private var errorIsTokenRelated: Bool {
        switch lastError {
        case .tokenRequired, .invalidToken: return true
        default: return false
        }
    }

    /// The site responded as a Nightscout instance, even if it needs a token.
    var addressReachable: Bool {
        isConnected || errorIsTokenRelated
    }

    /// The site is reachable but requires a token we don't have yet.
    var addressNeedsToken: Bool {
        !isConnected && errorIsTokenRelated
    }

    @Published var webSocketEnabled: Bool = Storage.shared.webSocketEnabled.value {
        didSet {
            Storage.shared.webSocketEnabled.value = webSocketEnabled
            if webSocketEnabled {
                NightscoutSocketManager.shared.connectIfNeeded()
            } else {
                NightscoutSocketManager.shared.disconnect()
                triggerRefresh()
            }
        }
    }

    @Published var webSocketStatus: String = "Disconnected"

    var webSocketStatusColor: Color {
        switch NightscoutSocketManager.shared.connectionState {
        case .authenticated: return .green
        case .connecting, .connected: return .orange
        case .disconnected: return .secondary
        case .error: return .red
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var checkStatusSubject = PassthroughSubject<Void, Never>()
    private var checkStatusWorkItem: DispatchWorkItem?

    /// While confirming a freshly provisioned token, the retry loop owns the
    /// status label, so the ordinary debounced check is suppressed to avoid
    /// flickering "Invalid Token" before the server has caught up.
    private var isConfirmingProvisionedToken = false

    /// Set when a token we just created is correct (the create call returned its
    /// id, so the secret was valid and the token is a deterministic function of
    /// it) but the site hasn't started accepting it yet. Some hosts only reload
    /// their auth cache on a restart, which can take minutes — far longer than we
    /// can spin during onboarding — so this is treated as a success-pending state
    /// the user can proceed from, not an error.
    @Published private(set) var provisionedTokenPending = false

    /// True while a read-only token is being created from the API secret.
    @Published var isProvisioningToken = false

    /// The most recent token-provisioning failure, for inline display.
    @Published var tokenProvisionError: String?

    init() {
        initialURL = Storage.shared.url.value
        initialToken = Storage.shared.token.value
        isFreshSetup = initialURL.isEmpty

        setupDebounce()
        checkNightscoutStatus()
        observeWebSocketState()
    }

    private func setupDebounce() {
        checkStatusSubject
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.checkNightscoutStatus()
            }
            .store(in: &cancellables)
    }

    private func triggerCheckStatus() {
        checkStatusWorkItem?.cancel()

        // Any manual edit invalidates a pending-provisioned state.
        provisionedTokenPending = false
        nightscoutStatus = "Checking..."

        checkStatusWorkItem = DispatchWorkItem {
            self.checkStatusSubject.send()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: checkStatusWorkItem!)
    }

    func processURL(_ value: String) {
        var useTokenUrl = false

        if let urlComponents = URLComponents(string: value), let queryItems = urlComponents.queryItems {
            if let tokenItem = queryItems.first(where: { $0.name.lowercased() == "token" }) {
                let tokenPattern = "^[^-\\s]+-[0-9a-fA-F]{16}$"
                if let token = tokenItem.value, let _ = token.range(of: tokenPattern, options: .regularExpression) {
                    var baseComponents = urlComponents
                    baseComponents.queryItems = nil
                    if let baseURL = baseComponents.string {
                        nightscoutToken = token
                        nightscoutURL = baseURL
                        useTokenUrl = true
                    }
                }
            }
        }

        if !useTokenUrl {
            let filtered = value.replacingOccurrences(of: "[^A-Za-z0-9:/._-]", with: "", options: .regularExpression).lowercased()
            var cleanURL = filtered
            while cleanURL.count > 8, cleanURL.last == "/" {
                cleanURL = String(cleanURL.dropLast())
            }
            nightscoutURL = cleanURL
        }
    }

    func checkNightscoutStatus() {
        if isConfirmingProvisionedToken { return }
        NightscoutUtils.verifyURLAndToken { error, _, nsWriteAuth, nsAdminAuth in
            DispatchQueue.main.async {
                Storage.shared.nsWriteAuth.value = nsWriteAuth
                Storage.shared.nsAdminAuth.value = nsAdminAuth

                self.updateStatusLabel(error: error)
            }
        }
    }

    /// Applies a token that LoopFollow just created and confirms it works.
    ///
    /// A freshly created subject isn't always recognized immediately: each
    /// Nightscout server instance only reloads its in-memory subject cache on a
    /// write, and multi-instance deployments don't share that cache — so the
    /// first validation can be routed to an instance that hasn't caught up yet.
    /// Rather than fail (and make the user tap again), we poll for a few seconds
    /// with a reassuring status before surfacing any error.
    func confirmProvisionedToken(_ token: String) {
        isConfirmingProvisionedToken = true
        provisionedTokenPending = false
        isConnected = false
        nightscoutStatus = "Finishing connection…"
        nightscoutToken = token
        verifyProvisionedTokenLoop(attempt: 0)
    }

    private func verifyProvisionedTokenLoop(attempt: Int) {
        let maxAttempts = 8
        NightscoutUtils.verifyURLAndToken { [weak self] error, _, nsWriteAuth, nsAdminAuth in
            DispatchQueue.main.async {
                guard let self else { return }
                if error == nil {
                    self.isConfirmingProvisionedToken = false
                    self.provisionedTokenPending = false
                    Storage.shared.nsWriteAuth.value = nsWriteAuth
                    Storage.shared.nsAdminAuth.value = nsAdminAuth
                    self.updateStatusLabel(error: nil)
                } else if attempt + 1 < maxAttempts {
                    self.nightscoutStatus = "Finishing connection…"
                    let delay = min(0.5 + Double(attempt) * 0.25, 2.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.verifyProvisionedTokenLoop(attempt: attempt + 1)
                    }
                } else {
                    // The token is correct but the site hasn't started accepting
                    // it yet. Surface a calm "pending" state the user can proceed
                    // from rather than a red error.
                    self.isConfirmingProvisionedToken = false
                    self.provisionedTokenPending = true
                    self.lastError = nil
                }
            }
        }
    }

    // MARK: - Token provisioning from API secret

    /// Nightscout access tokens look like `name-<16 hex>`; anything else the user
    /// puts in the token field — most often their API secret — won't match.
    private static let tokenFormat = "^[^-\\s]+-[0-9a-fA-F]{16}$"

    private func looksLikeToken(_ value: String) -> Bool {
        value.range(of: Self.tokenFormat, options: .regularExpression) != nil
    }

    /// True when the token field holds something that isn't a token and the site
    /// rejected it — most likely the user pasted their API secret instead of a
    /// token. Drives the "create a token from this" affordance.
    var tokenLooksLikeSecret: Bool {
        guard !nightscoutToken.isEmpty, !looksLikeToken(nightscoutToken) else { return false }
        switch lastError {
        case .invalidToken, .tokenRequired: return true
        default: return false
        }
    }

    /// Creates (or reuses) a read-only token from the given API secret and applies
    /// it. The secret authorizes the create call only and is never stored.
    func createReadOnlyToken(fromSecret secret: String) {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        tokenProvisionError = nil
        isProvisioningToken = true
        let url = nightscoutURL

        Task {
            do {
                let token = try await NightscoutUtils.provisionReadOnlyToken(url: url, secret: trimmed)
                await MainActor.run {
                    self.isProvisioningToken = false
                    self.confirmProvisionedToken(token)
                }
            } catch {
                await MainActor.run {
                    self.isProvisioningToken = false
                    self.tokenProvisionError = NightscoutSettingsViewModel.provisioningMessage(for: error)
                }
            }
        }
    }

    static func provisioningMessage(for error: Error) -> String {
        guard let nsError = error as? NightscoutUtils.NightscoutError else {
            return "Could not create a token. Please try again."
        }
        switch nsError {
        case .invalidToken:
            return "That API secret was rejected. Check it and try again."
        case .invalidURL, .emptyAddress:
            return "Please enter a valid site URL first."
        case .siteNotFound:
            return "Couldn't reach that site. Check the URL."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .tokenRequired, .unknown:
            return "Could not create a token. Please try again."
        }
    }

    func updateStatusLabel(error: NightscoutUtils.NightscoutError?) {
        lastError = error
        if let error = error {
            isConnected = false
            switch error {
            case .invalidURL:
                nightscoutStatus = "Invalid URL"
            case .networkError:
                nightscoutStatus = "Network Error"
            case .invalidToken:
                nightscoutStatus = "Invalid Token"
            case .tokenRequired:
                nightscoutStatus = "Token Required"
            case .siteNotFound:
                nightscoutStatus = "Site Not Found"
            case .unknown:
                nightscoutStatus = "Unknown Error"
            case .emptyAddress:
                nightscoutStatus = "Address Empty"
            }
            NightscoutSocketManager.shared.disconnect()
        } else {
            isConnected = true
            let authStatus: String
            if Storage.shared.nsAdminAuth.value {
                authStatus = "Admin"
            } else {
                authStatus = "Read" + (Storage.shared.nsWriteAuth.value ? " & Write" : "")
            }

            nightscoutStatus = "OK (\(authStatus))"

            if nightscoutURL != initialURL || nightscoutToken != initialToken {
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
            }
        }
    }

    private func triggerRefresh() {
        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
    }

    // MARK: - Adaptive status (onboarding)

    enum ConnectionStatusKind {
        case idle
        case checking
        case needsToken
        case pending
        case connected
        case error
    }

    /// A coarse status used to drive the onboarding status pill's color and icon.
    var statusKind: ConnectionStatusKind {
        if isConfirmingProvisionedToken { return .checking }
        if nightscoutURL.isEmpty { return .idle }
        if isConnected { return .connected }
        // Token created and correct, just not accepted by the site yet.
        if provisionedTokenPending { return .pending }
        if nightscoutStatus == "Checking..." { return .checking }
        // The site is reachable and simply needs a token — that's an expected
        // step, not an error, so it's shown positively rather than red.
        if addressNeedsToken { return .needsToken }
        return .error
    }

    /// A friendly, contextual status line that updates as the user fills fields,
    /// rather than a fixed "Status" label that can read as stale.
    var friendlyStatus: String {
        switch statusKind {
        case .idle:
            return "Enter your site address to connect."
        case .checking:
            return isConfirmingProvisionedToken ? "Finishing connection…" : "Checking your connection…"
        case .needsToken:
            return "Site found — it needs a token."
        case .pending:
            return "Token created. Your site can take a few minutes to start accepting it — you can continue."
        case .connected:
            if Storage.shared.nsAdminAuth.value { return "Connected — admin access" }
            if Storage.shared.nsWriteAuth.value { return "Connected — read & write" }
            return "Connected — read-only"
        case .error:
            return nightscoutStatus
        }
    }

    private func observeWebSocketState() {
        updateWebSocketStatus()
        NotificationCenter.default.publisher(for: .nightscoutSocketStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateWebSocketStatus()
            }
            .store(in: &cancellables)
    }

    private func updateWebSocketStatus() {
        switch NightscoutSocketManager.shared.connectionState {
        case .disconnected: webSocketStatus = "Disconnected"
        case .connecting: webSocketStatus = "Connecting..."
        case .connected: webSocketStatus = "Connected"
        case .authenticated: webSocketStatus = "Connected"
        case .error: webSocketStatus = "Error"
        }
    }
}
