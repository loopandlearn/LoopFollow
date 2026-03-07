// APNSClient.swift
// Philippe Achkar
// 2026-03-07

import Foundation

class APNSClient {

    static let shared = APNSClient()
    private init() {}

    // MARK: - Configuration

    private let bundleID = Bundle.main.bundleIdentifier ?? "com.apple.unknown"
    private let apnsHost = "https://api.push.apple.com"

    // MARK: - JWT Cache

    private var cachedToken: String?
    private var tokenGeneratedAt: Date?
    private let tokenTTL: TimeInterval = 55 * 60

    private func validToken() throws -> String {
        let now = Date()
        if let token = cachedToken,
           let generatedAt = tokenGeneratedAt,
           now.timeIntervalSince(generatedAt) < tokenTTL {
            return token
        }
        let newToken = try APNSJWTGenerator.generateToken()
        cachedToken = newToken
        tokenGeneratedAt = now
        LogManager.shared.log(category: .general, message: "APNs JWT refreshed", isDebug: true)
        return newToken
    }

    // MARK: - Send Live Activity Update

    func sendLiveActivityUpdate(
        pushToken: String,
        state: GlucoseLiveActivityAttributes.ContentState
    ) async {
        do {
            let jwt = try validToken()
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

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    LogManager.shared.log(category: .general, message: "APNs push sent successfully", isDebug: true)
                } else {
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
            "unit": snapshot.unit.rawValue
        ]

        if let iob = snapshot.iob { snapshotDict["iob"] = iob }
        if let cob = snapshot.cob { snapshotDict["cob"] = cob }
        if let projected = snapshot.projected { snapshotDict["projected"] = projected }

        let contentState: [String: Any] = [
            "snapshot": snapshotDict,
            "seq": state.seq,
            "reason": state.reason,
            "producedAt": state.producedAt.timeIntervalSince1970
        ]

        let payload: [String: Any] = [
            "aps": [
                "timestamp": Int(Date().timeIntervalSince1970),
                "event": "update",
                "content-state": contentState
            ]
        ]

        return try? JSONSerialization.data(withJSONObject: payload)
    }
}
