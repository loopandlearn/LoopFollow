// LoopFollow
// WatchSession.swift

import Foundation
import WatchConnectivity
import WatchKit
import WidgetKit

/// Watch side of the phone link. The phone is the main source: it sends
/// `WatchState` and relays commands. While the phone's data is stale and the
/// phone does not answer, the watch fetches from Nightscout or Dexcom itself
/// and sends commands directly.
@MainActor
final class WatchSession: NSObject, ObservableObject {
    static let shared = WatchSession()

    /// Phone data older than this hands over to the watch's own fetching.
    static let phoneStaleAfter: TimeInterval = 10 * 60
    /// Minimum time between two fetches made by the watch itself.
    private static let standaloneInterval: TimeInterval = 60

    @Published private(set) var state: WatchState?
    @Published private(set) var isReachable = false

    private var session: WCSession { WCSession.default }
    private var credentials: WatchCredentials?
    private var lastPhoneBuiltAt: Date
    private var lastStandaloneAttempt: Date = .distantPast

    override private init() {
        let stored = WatchStateStore.load()
        state = stored
        lastPhoneBuiltAt = stored?.phoneBuiltAt ?? .distantPast
        credentials = WatchKeychain.load()
        super.init()
    }

    func activate() {
        guard WCSession.isSupported(), session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    /// Commands go through the phone, or directly when the phone sent what that needs.
    var canSendCommands: Bool {
        isReachable || credentials?.remote != nil
    }

    /// True while the phone's latest state is recent enough to rely on.
    var isPhoneDataFresh: Bool {
        Date().timeIntervalSince(lastPhoneBuiltAt) < Self.phoneStaleAfter
    }

    /// Asks the phone for fresh state; the application context covers the case
    /// where the phone is out of reach.
    func requestState() {
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchMessageKey.requestState: true], replyHandler: { reply in
            guard let data = reply[WatchState.contextKey] as? Data else { return }
            Task { @MainActor in self.applyFromPhone(data) }
        }, errorHandler: nil)
    }

    /// Fetches from Nightscout or Dexcom when the phone's data is stale and the phone does not answer.
    func refreshIfNeeded() async {
        guard !isPhoneDataFresh else { return }
        if session.activationState == .activated, session.isReachable {
            requestState()
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !isPhoneDataFresh else { return }
        }
        guard let credentials, credentials.hasDataSource else {
            LogManager.shared.log(category: .general, message: "Phone data is stale, but the watch has no data source credentials yet")
            return
        }
        guard Date().timeIntervalSince(lastStandaloneAttempt) >= Self.standaloneInterval else { return }
        lastStandaloneAttempt = Date()
        do {
            let fetched = try await StandaloneFetcher.fetch(credentials: credentials, base: state)
            guard !isPhoneDataFresh else { return }
            store(fetched)
            LogManager.shared.log(category: .nightscout, message: "Standalone fetch: \(fetched.readings.count) readings")
        } catch {
            LogManager.shared.log(category: .nightscout, message: "Standalone fetch failed: \(error.localizedDescription)")
        }
    }

    /// Sends a command through the phone when it is reachable, otherwise directly.
    /// Falls back to sending directly only when the phone turned out to be out of
    /// reach before the command was delivered; a command that may have reached
    /// the phone is never sent a second time.
    func send(_ action: WatchCommand.Action) async -> WatchCommandReply {
        if session.activationState == .activated, session.isReachable {
            switch await sendThroughPhone(action) {
            case let .replied(reply): return reply
            case .notDelivered: break
            }
        }
        if case .snoozeAlarm = action {
            return WatchCommandReply(success: false, message: "Snoozing needs the iPhone, which is not reachable right now.")
        }
        guard let credentials, let config = state?.remote else {
            return WatchCommandReply(success: false, message: "iPhone not reachable. Open LoopFollow on the iPhone and keep it near the watch.")
        }
        return await DirectCommandSender.send(action, credentials: credentials, config: config)
    }

    private enum PhoneSendResult {
        case replied(WatchCommandReply)
        /// WatchConnectivity reported the phone unreachable, so the command never left the watch.
        case notDelivered
    }

    private func sendThroughPhone(_ action: WatchCommand.Action) async -> PhoneSendResult {
        guard let data = try? JSONEncoder().encode(WatchCommand(action: action)) else {
            return .replied(WatchCommandReply(success: false, message: "Could not encode the command."))
        }
        let noReply = WatchCommandReply(
            success: false,
            message: "No reply from the iPhone. The command may still have been sent: check Loop or Trio before trying again."
        )
        return await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            session.sendMessage([WatchCommand.messageKey: data], replyHandler: { reply in
                let result = (reply[WatchCommandReply.messageKey] as? Data)
                    .flatMap { try? JSONDecoder().decode(WatchCommandReply.self, from: $0) }
                once.resume(.replied(result ?? WatchCommandReply(success: false, message: "Unexpected reply from the iPhone.")))
            }, errorHandler: { error in
                once.resume((error as? WCError)?.code == .notReachable ? .notDelivered : .replied(noReply))
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.phoneReplyTimeout) {
                once.resume(.replied(noReply))
            }
        }
    }

    /// Longest wait for the phone's verdict before telling the user it is unknown.
    private static let phoneReplyTimeout: TimeInterval = 30

    /// Lets a WatchConnectivity background task finish once queued data has been delivered.
    func waitForPendingContent() async {
        activate()
        for _ in 0 ..< 40 {
            if session.activationState == .activated, !session.hasContentPending { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    static let backgroundRefreshID = "standalone"

    /// Schedules the next background check for stale phone data.
    func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(15 * 60),
            userInfo: Self.backgroundRefreshID as NSString
        ) { _ in }
    }

    private func applyFromPhone(_ data: Data) {
        guard let incoming = WatchState.decode(data), incoming.builtAt > lastPhoneBuiltAt else { return }
        lastPhoneBuiltAt = incoming.builtAt
        store(incoming)
    }

    private func store(_ incoming: WatchState) {
        guard let encoded = incoming.encoded() else { return }
        let newAlarm = incoming.alarm != nil && incoming.alarm?.id != state?.alarm?.id
        let complicationChanged = Self.complicationKey(incoming) != state.map(Self.complicationKey)
        state = incoming
        WatchStateStore.save(encoded)
        // Widget reloads are budgeted, so only reload when something the complication shows has changed.
        if complicationChanged {
            WidgetCenter.shared.reloadAllTimelines()
        }

        if newAlarm, WKApplication.shared().applicationState == .active {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private static func complicationKey(_ state: WatchState) -> String {
        let s = state.snapshot
        return "\(s?.updatedAt.timeIntervalSince1970 ?? 0)|\(s?.unit.rawValue ?? "")|\(state.lowMgdl)|\(state.highMgdl)|\(state.colorBGText)"
    }

    private func receiveCredentials(_ data: Data) {
        guard let received = try? JSONDecoder().decode(WatchCredentials.self, from: data) else {
            LogManager.shared.log(category: .general, message: "Could not decode credentials from the phone")
            return
        }
        credentials = received
        WatchKeychain.save(received)
        LogManager.shared.log(category: .general, message: "Credentials received (remote commands: \(received.remote != nil))")
    }

    /// Asks the phone for credentials when the watch has none, e.g. after a reinstall.
    private func requestCredentialsIfMissing() {
        guard credentials == nil, session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage([WatchCredentials.requestKey: true], replyHandler: { reply in
                guard let data = reply[WatchCredentials.userInfoKey] as? Data else { return }
                Task { @MainActor in self.receiveCredentials(data) }
            }, errorHandler: nil)
        } else {
            session.transferUserInfo([WatchCredentials.requestKey: true])
        }
    }
}

extension WatchSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {
        let context = session.receivedApplicationContext[WatchState.contextKey] as? Data
        let reachable = session.isReachable
        Task { @MainActor in
            if let context { self.applyFromPhone(context) }
            self.isReachable = reachable
            self.requestState()
            self.requestCredentialsIfMissing()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if reachable {
                self.requestState()
                self.requestCredentialsIfMissing()
            }
        }
    }

    nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchState.contextKey] as? Data else { return }
        Task { @MainActor in self.applyFromPhone(data) }
    }

    nonisolated func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let credentials = message[WatchCredentials.userInfoKey] as? Data else { return }
        Task { @MainActor in self.receiveCredentials(credentials) }
    }

    nonisolated func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let state = userInfo[WatchState.contextKey] as? Data
        let credentials = userInfo[WatchCredentials.userInfoKey] as? Data
        Task { @MainActor in
            if let state { self.applyFromPhone(state) }
            if let credentials { self.receiveCredentials(credentials) }
        }
    }
}

/// Resumes a continuation at most once, from whichever callback comes first.
private final class ResumeOnce<T>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
