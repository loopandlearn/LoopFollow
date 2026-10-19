// LoopFollow
// WatchSessionManager.swift

import Combine
import Foundation
import WatchConnectivity

/// Phone side of the Apple Watch link. Publishes `WatchState` as the
/// application context and relays commands from the watch to
/// `WatchCommandHandler`.
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    /// Complication pushes are rationed by watchOS (about 50 per day), so they
    /// are only used when a new reading arrives and this long has passed.
    private let complicationTransferInterval: TimeInterval = 15 * 60

    private var lastSentState: WatchState?
    private var lastSentCredentials: WatchCredentials?
    private var lastComplicationTransfer: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()
    private lazy var coalescer = RefreshCoalescer(delay: 2) { [weak self] reason in
        self?.publish(reason: reason)
    }

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
        observeSettings()
    }

    /// Schedules a state update. Safe to call often; requests are coalesced.
    func requestUpdate(reason: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.requestUpdate(reason: reason) }
            return
        }
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        coalescer.request(reason: reason)
    }

    private func observeSettings() {
        let triggers: [AnyPublisher<Void, Never>] = [
            Observable.shared.currentAlarm.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.watchRemoteCommands.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.remoteType.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.colorBGText.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.units.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.mealWithBolus.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.mealWithFatProtein.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.infoDisplayItems.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.graphTimeZoneEnabled.$value.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .dropFirst(triggers.count)
            .sink { [weak self] in self?.requestUpdate(reason: "settings") }
            .store(in: &cancellables)

        let credentialTriggers: [AnyPublisher<Void, Never>] = [
            Storage.shared.url.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.token.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.shareUserName.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.sharePassword.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.shareServer.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.remoteType.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.watchRemoteCommands.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.deviceToken.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.bundleId.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.productionEnvironment.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.teamId.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.lfApnsKey.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.lfKeyId.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.remoteApnsKey.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.remoteKeyId.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.user.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.sharedSecret.$value.map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.loopAPNSQrCodeURL.$value.map { _ in () }.eraseToAnyPublisher(),
            Observable.shared.loopFollowDeviceToken.$value.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(credentialTriggers)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.sendCredentialsIfChanged(force: false) }
            .store(in: &cancellables)
    }

    /// Sends the credentials when they differ from what was last sent, or when
    /// the watch asks for them. They never travel with the state updates.
    private func sendCredentialsIfChanged(force: Bool) {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let credentials = WatchCredentialsBuilder.build()
        guard force || credentials != lastSentCredentials,
              let data = try? JSONEncoder().encode(credentials)
        else { return }
        for transfer in session.outstandingUserInfoTransfers where transfer.userInfo[WatchCredentials.userInfoKey] != nil {
            transfer.cancel()
        }
        session.transferUserInfo([WatchCredentials.userInfoKey: data])
        lastSentCredentials = credentials
        LogManager.shared.log(category: .general, message: "[Watch] credentials sent")
    }

    /// Sends the info table and statistics to the watch whenever they change.
    func observe(_ infoManager: InfoManager, stats: StatsDisplayModel) {
        infoManager.objectWillChange
            .sink { [weak self] in self?.requestUpdate(reason: "info") }
            .store(in: &cancellables)
        stats.objectWillChange
            .sink { [weak self] in self?.requestUpdate(reason: "stats") }
            .store(in: &cancellables)
    }

    private func publish(reason: String) {
        guard let session, session.activationState == .activated else { return }
        let state = WatchStateBuilder.build()
        guard let data = state.encoded() else { return }

        do {
            try session.updateApplicationContext([WatchState.contextKey: data])
        } catch {
            LogManager.shared.log(category: .general, message: "[Watch] context update failed: \(error.localizedDescription)")
        }

        let newReading = state.snapshot?.updatedAt != lastSentState?.snapshot?.updatedAt
        if newReading,
           session.isComplicationEnabled,
           session.remainingComplicationUserInfoTransfers > 0,
           Date().timeIntervalSince(lastComplicationTransfer) >= complicationTransferInterval
        {
            session.transferCurrentComplicationUserInfo([WatchState.contextKey: data])
            lastComplicationTransfer = Date()
        }

        lastSentState = state
        LogManager.shared.log(category: .general, message: "[Watch] state sent (\(data.count) bytes) reason=\(reason)", isDebug: true)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            LogManager.shared.log(category: .general, message: "[Watch] activation failed: \(error.localizedDescription)")
            return
        }
        if state == .activated {
            requestUpdate(reason: "activated")
            DispatchQueue.main.async { self.sendCredentialsIfChanged(force: false) }
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Required when the user switches to another watch.
        session.activate()
    }

    func sessionWatchStateDidChange(_: WCSession) {
        requestUpdate(reason: "watchStateChanged")
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if message[WatchCredentials.requestKey] != nil {
                self.sendCredentialsIfChanged(force: true)
                replyHandler([:])
                return
            }

            if message[WatchMessageKey.requestState] != nil {
                let data = WatchStateBuilder.build().encoded() ?? Data()
                replyHandler([WatchState.contextKey: data])
                return
            }

            guard let data = message[WatchCommand.messageKey] as? Data,
                  let command = try? JSONDecoder().decode(WatchCommand.self, from: data)
            else {
                Self.reply(WatchCommandReply(success: false, message: "Unknown request."), to: replyHandler)
                return
            }

            WatchCommandHandler.shared.handle(command) { result in
                Self.reply(result, to: replyHandler)
                self.requestUpdate(reason: "command")
            }
        }
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo[WatchCredentials.requestKey] != nil {
            DispatchQueue.main.async { self.sendCredentialsIfChanged(force: true) }
        }
    }

    private static func reply(_ reply: WatchCommandReply, to handler: ([String: Any]) -> Void) {
        let data = (try? JSONEncoder().encode(reply)) ?? Data()
        handler([WatchCommandReply.messageKey: data])
    }
}
