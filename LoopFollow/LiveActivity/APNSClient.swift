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

    private var lfKeyId: String {
        Storage.shared.lfKeyId.value
    }

    private var lfTeamId: String {
        BuildDetails.default.teamID ?? ""
    }

    private var lfApnsKey: String {
        Storage.shared.lfApnsKey.value
    }

    // MARK: - Send Live Activity Update

    func sendLiveActivityUpdate(
        pushToken: String,
        state: GlucoseLiveActivityAttributes.ContentState,
    ) async {
        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: lfKeyId, teamId: lfTeamId, apnsKey: lfApnsKey) else {
            LogManager.shared.log(category: .apns, message: "APNs failed to generate JWT for Live Activity push")
            return
        }

        let payload = buildPayload(state: state)

        guard let url = URL(string: "\(apnsHost)/3/device/\(pushToken)") else {
            LogManager.shared.log(category: .apns, message: "APNs invalid URL", isDebug: true)
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
                    LogManager.shared.log(category: .apns, message: "APNs push sent successfully", isDebug: true)

                case 400:
                    let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                    LogManager.shared.log(category: .apns, message: "APNs bad request (400) — malformed payload: \(responseBody)")

                case 403:
                    // JWT rejected — force regenerate on next push
                    JWTManager.shared.invalidateCache()
                    LogManager.shared.log(category: .apns, message: "APNs JWT rejected (403) — token cache cleared, will regenerate")

                case 404, 410:
                    // Activity token not found or expired — end and restart on next refresh
                    let reason = httpResponse.statusCode == 410 ? "expired (410)" : "not found (404)"
                    LogManager.shared.log(category: .apns, message: "APNs token \(reason) — restarting Live Activity")
                    LiveActivityManager.shared.handleExpiredToken()

                case 429:
                    LogManager.shared.log(category: .apns, message: "APNs rate limited (429) — will retry on next refresh")

                case 500 ... 599:
                    let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                    LogManager.shared.log(category: .apns, message: "APNs server error (\(httpResponse.statusCode)) — will retry on next refresh: \(responseBody)")

                default:
                    let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                    LogManager.shared.log(category: .apns, message: "APNs push failed status=\(httpResponse.statusCode) body=\(responseBody)")
                }
            }

        } catch {
            LogManager.shared.log(category: .apns, message: "APNs error: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Live Activity Start (push-to-start, iOS 17.2+)

    enum PushToStartResult {
        case success
        case rateLimited
        case tokenInvalid
        case failed
    }

    func sendLiveActivityStart(
        pushToStartToken: String,
        attributesTitle: String,
        state: GlucoseLiveActivityAttributes.ContentState,
        staleDate: Date,
    ) async -> PushToStartResult {
        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: lfKeyId, teamId: lfTeamId, apnsKey: lfApnsKey) else {
            LogManager.shared.log(category: .apns, message: "APNs failed to generate JWT for Live Activity push-to-start")
            return .failed
        }

        let payload = buildStartPayload(attributesTitle: attributesTitle, state: state, staleDate: staleDate)

        let host = apnsHost
        guard let url = URL(string: "\(host)/3/device/\(pushToStartToken)") else {
            LogManager.shared.log(category: .apns, message: "APNs invalid URL (push-to-start)", isDebug: true)
            return .failed
        }

        let environment = BuildDetails.default.isTestFlightBuild() ? "production" : "sandbox"
        LogManager.shared.log(
            category: .apns,
            message: "APNs push-to-start sending host=\(host) env=\(environment) tokenTail=…\(String(pushToStartToken.suffix(8)))"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("\(bundleID).push-type.liveactivity", forHTTPHeaderField: "apns-topic")
        request.setValue("liveactivity", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        // 10-minute expiry — long enough to survive a brief connectivity gap
        // while the glucose reading in the payload is still clinically meaningful.
        // The stale date (8 h) is too generous: delivering a start with hours-old
        // glucose data is worse than not starting at all.
        request.setValue("\(Int(Date().timeIntervalSince1970) + 10 * 60)", forHTTPHeaderField: "apns-expiration")
        // Collapse key prevents duplicate LA creation if two sends race (e.g., a
        // refresh tick and a user-initiated restart overlap).
        request.setValue("\(bundleID).la.start", forHTTPHeaderField: "apns-collapse-id")
        request.httpBody = payload

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                LogManager.shared.log(category: .apns, message: "APNs push-to-start: no HTTP response")
                return .failed
            }
            switch httpResponse.statusCode {
            case 200:
                LogManager.shared.log(category: .apns, message: "APNs push-to-start sent successfully")
                return .success
            case 403:
                JWTManager.shared.invalidateCache()
                LogManager.shared.log(category: .apns, message: "APNs push-to-start JWT rejected (403) — token cache cleared")
                return .failed
            case 404, 410:
                // Push-to-start token rotated or invalid — caller should clear stored token
                // so the next pushToStartTokenUpdates delivery overwrites it.
                let reason = httpResponse.statusCode == 410 ? "expired (410)" : "not found (404)"
                LogManager.shared.log(category: .apns, message: "APNs push-to-start token \(reason) — clearing stored token")
                return .tokenInvalid
            case 429:
                LogManager.shared.log(category: .apns, message: "APNs push-to-start rate limited (429)")
                return .rateLimited
            default:
                let responseBody = String(data: data, encoding: .utf8) ?? "empty"
                LogManager.shared.log(category: .apns, message: "APNs push-to-start failed status=\(httpResponse.statusCode) body=\(responseBody)")
                return .failed
            }
        } catch {
            LogManager.shared.log(category: .apns, message: "APNs push-to-start error: \(error.localizedDescription)")
            return .failed
        }
    }

    // alert with empty title/body + interruption-level: passive is what
    // keeps both phone and watch silent during adoption — iOS drops the
    // start payload entirely if alert is missing, so the keys must be
    // present even though the strings are empty.
    private func buildStartPayload(
        attributesTitle: String,
        state: GlucoseLiveActivityAttributes.ContentState,
        staleDate: Date,
    ) -> Data? {
        guard let contentStateDict = contentStateDictionary(state: state) else { return nil }

        let payload: [String: Any] = [
            "aps": [
                "timestamp": Int(Date().timeIntervalSince1970),
                "event": "start",
                "stale-date": Int(staleDate.timeIntervalSince1970),
                "attributes-type": "GlucoseLiveActivityAttributes",
                "attributes": ["title": attributesTitle],
                "content-state": contentStateDict,
                "alert": [
                    "title": "",
                    "body": "",
                ],
                "interruption-level": "passive",
            ],
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    // MARK: - Payload Builder

    private func buildPayload(state: GlucoseLiveActivityAttributes.ContentState) -> Data? {
        guard let contentState = contentStateDictionary(state: state) else { return nil }
        let payload: [String: Any] = [
            "aps": [
                "timestamp": Int(Date().timeIntervalSince1970),
                "event": "update",
                "content-state": contentState,
            ],
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    private func contentStateDictionary(state: GlucoseLiveActivityAttributes.ContentState) -> [String: Any]? {
        let snapshot = state.snapshot

        var snapshotDict: [String: Any] = [
            "glucose": snapshot.glucose,
            "delta": snapshot.delta,
            "trend": snapshot.trend.rawValue,
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
            "unit": snapshot.unit.rawValue,
        ]

        snapshotDict["isNotLooping"] = snapshot.isNotLooping
        snapshotDict["showRenewalOverlay"] = snapshot.showRenewalOverlay
        if let iob = snapshot.iob { snapshotDict["iob"] = iob }
        if let cob = snapshot.cob { snapshotDict["cob"] = cob }
        if let projected = snapshot.projected { snapshotDict["projected"] = projected }
        if let override = snapshot.override { snapshotDict["override"] = override }
        if let recBolus = snapshot.recBolus { snapshotDict["recBolus"] = recBolus }
        if let battery = snapshot.battery { snapshotDict["battery"] = battery }
        if let pumpBattery = snapshot.pumpBattery { snapshotDict["pumpBattery"] = pumpBattery }
        if !snapshot.basalRate.isEmpty { snapshotDict["basalRate"] = snapshot.basalRate }
        if let pumpReservoirU = snapshot.pumpReservoirU { snapshotDict["pumpReservoirU"] = pumpReservoirU }
        if let autosens = snapshot.autosens { snapshotDict["autosens"] = autosens }
        if let tdd = snapshot.tdd { snapshotDict["tdd"] = tdd }
        if let targetLowMgdl = snapshot.targetLowMgdl { snapshotDict["targetLowMgdl"] = targetLowMgdl }
        if let targetHighMgdl = snapshot.targetHighMgdl { snapshotDict["targetHighMgdl"] = targetHighMgdl }
        if let isfMgdlPerU = snapshot.isfMgdlPerU { snapshotDict["isfMgdlPerU"] = isfMgdlPerU }
        if let carbRatio = snapshot.carbRatio { snapshotDict["carbRatio"] = carbRatio }
        if let carbsToday = snapshot.carbsToday { snapshotDict["carbsToday"] = carbsToday }
        if let profileName = snapshot.profileName { snapshotDict["profileName"] = profileName }
        if snapshot.sageInsertTime > 0 { snapshotDict["sageInsertTime"] = snapshot.sageInsertTime }
        if snapshot.cageInsertTime > 0 { snapshotDict["cageInsertTime"] = snapshot.cageInsertTime }
        if snapshot.iageInsertTime > 0 { snapshotDict["iageInsertTime"] = snapshot.iageInsertTime }
        if let minBgMgdl = snapshot.minBgMgdl { snapshotDict["minBgMgdl"] = minBgMgdl }
        if let maxBgMgdl = snapshot.maxBgMgdl { snapshotDict["maxBgMgdl"] = maxBgMgdl }

        return [
            "snapshot": snapshotDict,
            "seq": state.seq,
            "reason": state.reason,
            "producedAt": state.producedAt.timeIntervalSince1970,
        ]
    }
}

#endif
