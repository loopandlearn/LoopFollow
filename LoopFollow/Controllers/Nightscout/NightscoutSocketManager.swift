// LoopFollow
// NightscoutSocketManager.swift

import Foundation
import SocketIO

class NightscoutSocketManager {
    static let shared = NightscoutSocketManager()

    enum ConnectionState: String {
        case disconnected
        case connecting
        case connected
        case authenticated
        case error
    }

    private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .nightscoutSocketStateChanged, object: nil)
            }
        }
    }

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var currentURL: String = ""
    private var currentToken: String = ""

    var onDataUpdate: (([String: Any]) -> Void)?

    private init() {}

    // MARK: - Public API

    func connectIfNeeded() {
        guard Storage.shared.webSocketEnabled.value else {
            disconnect()
            return
        }

        let url = Storage.shared.url.value
        let token = Storage.shared.token.value

        guard !url.isEmpty else {
            disconnect()
            return
        }

        // Already connected to the same URL
        if connectionState == .authenticated || connectionState == .connecting || connectionState == .connected {
            if url == currentURL, token == currentToken {
                return
            }
            // URL or token changed, reconnect
            disconnect()
        }

        currentURL = url
        currentToken = token
        connect()
    }

    func disconnect() {
        socket?.removeAllHandlers()
        socket?.disconnect()
        manager?.disconnect()
        manager = nil
        socket = nil
        connectionState = .disconnected
        currentURL = ""
        currentToken = ""
    }

    // MARK: - Private

    private func connect() {
        guard let url = URL(string: currentURL) else {
            LogManager.shared.log(category: .websocket, message: "Invalid Nightscout URL for WebSocket")
            connectionState = .error
            return
        }

        connectionState = .connecting

        var config: SocketIOClientConfiguration = [
            .log(false),
            .compress,
            .forceWebsockets(false),
            .reconnects(true),
            .reconnectWait(5),
            .reconnectWaitMax(30),
        ]

        if !currentToken.isEmpty {
            config.insert(.connectParams(["token": currentToken]))
        }

        manager = SocketManager(socketURL: url, config: config)

        guard let mgr = manager else { return }
        socket = mgr.defaultSocket

        setupEventHandlers()
        socket?.connect()

        LogManager.shared.log(category: .websocket, message: "Connecting to Nightscout WebSocket at \(currentURL)")
    }

    private func setupEventHandlers() {
        guard let socket = socket else { return }

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            LogManager.shared.log(category: .websocket, message: "Socket connected, authorizing...")
            self.connectionState = .connected
            self.authorize()
        }

        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            guard let self = self else { return }
            let reason = (data.first as? String) ?? "unknown"
            LogManager.shared.log(category: .websocket, message: "Socket disconnected: \(reason)")
            self.connectionState = .disconnected
            // Immediately restore normal polling intervals
            NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
        }

        socket.on(clientEvent: .reconnect) { _, _ in
            LogManager.shared.log(category: .websocket, message: "Socket reconnecting...")
        }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            let errorMsg = (data.first as? String) ?? "unknown error"
            LogManager.shared.log(category: .websocket, message: "Socket error: \(errorMsg)")
            self?.connectionState = .error
        }

        socket.on("connected") { [weak self] _, _ in
            guard let self = self else { return }
            LogManager.shared.log(category: .websocket, message: "Authorized and receiving data")
            self.connectionState = .authenticated
        }

        socket.on("dataUpdate") { [weak self] data, _ in
            guard let self = self,
                  let payload = data.first as? [String: Any]
            else { return }

            LogManager.shared.log(category: .websocket, message: "Received dataUpdate (delta: \(payload["delta"] as? Bool ?? false))", isDebug: true)

            DispatchQueue.main.async {
                self.onDataUpdate?(payload)
            }
        }
    }

    private func authorize() {
        var authPayload: [String: Any] = [
            "client": "LoopFollow",
            "history": 1,
        ]

        // Nightscout's authorization.resolve() expects:
        // - "token" field for JWT tokens (verified via verifyJWT)
        // - "secret" field for access tokens (checked via doesAccessTokenExist)
        // LoopFollow uses access tokens (e.g. "readable-xxxx"), so pass as "secret".
        if !currentToken.isEmpty {
            authPayload["secret"] = currentToken
        }

        socket?.emit("authorize", authPayload)
    }
}

extension Notification.Name {
    static let nightscoutSocketStateChanged = Notification.Name("nightscoutSocketStateChanged")
}
