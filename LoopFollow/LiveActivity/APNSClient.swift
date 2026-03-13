// LoopFollow
// APNSClient.swift

// swiftformat:disable indent
#if !targetEnvironment(macCatalyst)

import Foundation

class APNSClient {
    static let shared = APNSClient()
    private init() {}

    // MARK: - Configuration

    private let bundleID = Bundle.main.bundleIdentifier ?? "com.apple.unknown"

    private var apnsHost: String {
        let isProduction = BuildDetails.default.isTestFlightBuild()
        return isProduction
            ? "https://api.push.apple.com"
            : "https://api.sandbox.push.apple.com"
    }

    private var lfKeyId: String { Storage.shared.lfKeyId.value }
    private var lfTeamId: String { BuildDetails.default.teamID ?? "" }
    private var lfApnsKey: String { Storage.shared.lfApnsKey.value }

    // MARK: - Send Live Activity Update

    func sendLiveActivityUpdate(
        pushToken: String,
        state: GlucoseLiveActivityAttributes.ContentState
    ) async {
        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: lfKeyId, teamId: lfTeamId, apnsKey: lfApnsKey) else {
            LogManager.shared.log(category: .general, message: "APNs failed to generate JWT for Live Activity push")
            return
        }

        let payload = buildPayload(state: state)

        guard let url = URL(string: "\(apnsHost)/3/device/\(pushToken)") else {
            LogManager.shared.log(category: .general, message: "APNs invalid URL", isDebug: true)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("\(bundleID).push-type.liveactivity", forHTTPHeaderField: "apns-topic")
        request.setValue("liveactivity", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.httpBody = payload

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    LogManager.shared.log(category: .general, message: "APNs push sent successfully", isDebug: true)

                case 400:
                    let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                    LogManager.shared.log(category: .general, message: "APNs bad request (400) — malformed payload: \(responseBody)")

                case 403:
                    // JWT rejected — force regenerate on next push
                    JWTManager.shared.invalidateCache()
                    LogManager.shared.log(category: .general, message: "APNs JWT rejected (403) — token cache cleared, will regenerate")

                case 404, 410:
                    // Activity token not found or expired — end and restart on next refresh
                    let reason = httpResponse.statusCode == 410 ? "expired (410)" : "not found (404)"
                    LogManager.shared.log(category: .general, message: "APNs token \(reason) — restarting Live Activity")
                    LiveActivityManager.shared.handleExpiredToken()

                case 429:
                    LogManager.shared.log(category: .general, message: "APNs rate limited (429) — will retry on next refresh")

                case 500 ... 599:
                    let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                    LogManager.shared.log(category: .general, message: "APNs server error (\(httpResponse.statusCode)) — will retry on next refresh: \(responseBody)")

                default:
                    let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                    LogManager.shared.log(category: .general, message: "APNs push failed status=\(httpResponse.statusCode) body=\(responseBody)")
                }
            }

        } catch {
            LogManager.shared.log(category: .general, message: "APNs error: \(error.localizedDescription)")
        }
    }

    // MARK: - Payload Builder

    private func buildPayload(state: GlucoseLiveActivityAttributes.ContentState) -> Data? {
        let snapshot = state.snapshot

        var snapshotDict: [String: Any] = [
            "glucose": snapshot.glucose,
            "delta": snapshot.delta,
            "trend": snapshot.trend.rawValue,
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
            "unit": snapshot.unit.rawValue,
        ]

        snapshotDict["isNotLooping"] = snapshot.isNotLooping
        if let iob = snapshot.iob { snapshotDict["iob"] = iob }
        if let cob = snapshot.cob { snapshotDict["cob"] = cob }
        if let projected = snapshot.projected { snapshotDict["projected"] = projected }

        let contentState: [String: Any] = [
            "snapshot": snapshotDict,
            "seq": state.seq,
            "reason": state.reason,
            "producedAt": state.producedAt.timeIntervalSince1970,
        ]

        let payload: [String: Any] = [
            "aps": [
                "timestamp": Int(Date().timeIntervalSince1970),
                "event": "update",
                "content-state": contentState,
            ],
        ]

        return try? JSONSerialization.data(withJSONObject: payload)
    }
}

#endif
