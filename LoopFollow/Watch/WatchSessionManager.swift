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
        ]
        Publishers.MergeMany(triggers)
            .dropFirst(triggers.count)
            .sink { [weak self] in self?.requestUpdate(reason: "settings") }
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

    private static func reply(_ reply: WatchCommandReply, to handler: ([String: Any]) -> Void) {
        let data = (try? JSONEncoder().encode(reply)) ?? Data()
        handler([WatchCommandReply.messageKey: data])
    }
}
