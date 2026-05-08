// LoopFollow
// WatchRemoteService.swift

import CryptoKit
import Foundation
import UserNotifications
import WatchKit

class WatchRemoteService {

    // MARK: - Local Notification Helper

    static func postLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        WKInterfaceDevice.current().play(.notification)
    }

    // MARK: - Public API

    static func sendBolus(amount: Double, config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        switch config.remoteType {
        case "Trio Remote Control":
            let payload = TRCPayload(
                user: config.trcUser,
                commandType: "bolus",
                timestamp: Date().timeIntervalSince1970,
                bolusAmount: amount
            )
            sendTRCCommand(payload: payload, config: config, completion: completion)
        case "Nightscout":
            let body: [String: Any] = [
                "enteredBy": "LoopFollow Watch",
                "eventType": "Correction Bolus",
                "insulin": amount,
                "created_at": ISO8601DateFormatter().string(from: Date()),
            ]
            postNightscoutTreatment(body: body, config: config, completion: completion)
        default:
            completion(false, "Remote type not supported")
        }
    }

    static func sendMeal(carbs: Int, protein: Int? = nil, fat: Int? = nil, entryTime: Date? = nil, config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        let timestamp = entryTime ?? Date()
        switch config.remoteType {
        case "Trio Remote Control":
            var payload = TRCPayload(
                user: config.trcUser,
                commandType: "meal",
                timestamp: Date().timeIntervalSince1970,
                carbs: carbs
            )
            payload.protein = protein
            payload.fat = fat
            if let entryTime = entryTime {
                payload.scheduledTime = entryTime.timeIntervalSince1970
            }
            sendTRCCommand(payload: payload, config: config, completion: completion)
        case "Nightscout":
            var body: [String: Any] = [
                "enteredBy": "LoopFollow Watch",
                "eventType": "Meal Bolus",
                "carbs": carbs,
                "created_at": ISO8601DateFormatter().string(from: timestamp),
            ]
            if let protein = protein { body["protein"] = protein }
            if let fat = fat { body["fat"] = fat }
            postNightscoutTreatment(body: body, config: config, completion: completion)
        default:
            completion(false, "Remote type not supported")
        }
    }

    static func sendTempTarget(target: Int, duration: Int, config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        switch config.remoteType {
        case "Trio Remote Control":
            let payload = TRCPayload(
                user: config.trcUser,
                commandType: "temp_target",
                timestamp: Date().timeIntervalSince1970,
                target: target,
                duration: duration
            )
            sendTRCCommand(payload: payload, config: config, completion: completion)
        case "Nightscout":
            let body: [String: Any] = [
                "enteredBy": "LoopFollow Watch",
                "eventType": "Temporary Target",
                "reason": "Manual",
                "targetTop": Double(target),
                "targetBottom": Double(target),
                "duration": duration,
                "created_at": ISO8601DateFormatter().string(from: Date()),
            ]
            postNightscoutTreatment(body: body, config: config, completion: completion)
        default:
            completion(false, "Remote type not supported")
        }
    }

    static func cancelTempTarget(config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        switch config.remoteType {
        case "Trio Remote Control":
            let payload = TRCPayload(
                user: config.trcUser,
                commandType: "cancel_temp_target",
                timestamp: Date().timeIntervalSince1970
            )
            sendTRCCommand(payload: payload, config: config, completion: completion)
        case "Nightscout":
            let body: [String: Any] = [
                "enteredBy": "LoopFollow Watch",
                "eventType": "Temporary Target",
                "reason": "Manual",
                "duration": 0,
                "created_at": ISO8601DateFormatter().string(from: Date()),
            ]
            postNightscoutTreatment(body: body, config: config, completion: completion)
        default:
            completion(false, "Remote type not supported")
        }
    }

    static func sendOverride(name: String, config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        switch config.remoteType {
        case "Trio Remote Control":
            let payload = TRCPayload(
                user: config.trcUser,
                commandType: "start_override",
                timestamp: Date().timeIntervalSince1970,
                overrideName: name
            )
            sendTRCCommand(payload: payload, config: config, completion: completion)
        default:
            completion(false, "Remote type not supported for overrides")
        }
    }

    static func cancelOverride(config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        switch config.remoteType {
        case "Trio Remote Control":
            let payload = TRCPayload(
                user: config.trcUser,
                commandType: "cancel_override",
                timestamp: Date().timeIntervalSince1970
            )
            sendTRCCommand(payload: payload, config: config, completion: completion)
        default:
            completion(false, "Remote type not supported for overrides")
        }
    }

    // MARK: - TRC (Trio Remote Control) via APNS

    private struct TRCPayload: Encodable {
        var user: String
        var commandType: String
        var timestamp: TimeInterval

        var bolusAmount: Double?
        var target: Int?
        var duration: Int?
        var carbs: Int?
        var protein: Int?
        var fat: Int?
        var overrideName: String?
        var scheduledTime: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case user
            case commandType = "command_type"
            case timestamp
            case bolusAmount = "bolus_amount"
            case target, duration, carbs, protein, fat, overrideName
            case scheduledTime = "scheduled_time"
        }
    }

    private struct APSPayload: Encodable {
        let contentAvailable: Int = 1
        let interruptionLevel: String = "time-sensitive"
        let alert: String

        enum CodingKeys: String, CodingKey {
            case contentAvailable = "content-available"
            case interruptionLevel = "interruption-level"
            case alert
        }
    }

    private struct APNSMessage: Encodable {
        let aps: APSPayload
        let encryptedData: String

        enum CodingKeys: String, CodingKey {
            case aps
            case encryptedData = "encrypted_data"
        }
    }

    private static func sendTRCCommand(payload: TRCPayload, config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        guard !config.trcSharedSecret.isEmpty,
              !config.trcApnsKey.isEmpty,
              !config.trcKeyId.isEmpty,
              !config.trcTeamId.isEmpty,
              !config.trcDeviceToken.isEmpty,
              !config.trcBundleId.isEmpty
        else {
            completion(false, "Missing TRC credentials")
            return
        }

        // Encrypt payload
        guard let encryptedData = encryptPayload(payload, sharedSecret: config.trcSharedSecret) else {
            completion(false, "Encryption failed")
            return
        }

        // Sign JWT
        guard let jwt = signJWT(keyId: config.trcKeyId, teamId: config.trcTeamId, apnsKey: config.trcApnsKey) else {
            completion(false, "JWT signing failed")
            return
        }

        // Build APNS request
        let host = config.trcProductionEnv ? "api.push.apple.com" : "api.sandbox.push.apple.com"
        guard let url = URL(string: "https://\(host)/3/device/\(config.trcDeviceToken)") else {
            completion(false, "Invalid APNS URL")
            return
        }

        let message = APNSMessage(
            aps: APSPayload(alert: "Remote Command: \(payload.commandType)"),
            encryptedData: encryptedData
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue("300", forHTTPHeaderField: "apns-expiration")
        request.setValue(config.trcBundleId, forHTTPHeaderField: "apns-topic")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        request.setValue(payload.commandType, forHTTPHeaderField: "apns-collapse-id")
        request.httpBody = try? JSONEncoder().encode(message)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    completion(true, nil)
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    completion(false, "APNS error: \(code)")
                }
            }
        }.resume()
    }

    // MARK: - CryptoKit AES-GCM Encryption

    private static func encryptPayload<T: Encodable>(_ payload: T, sharedSecret: String) -> String? {
        guard let secretData = sharedSecret.data(using: .utf8) else { return nil }
        let keyHash = SHA256.hash(data: secretData)
        let symmetricKey = SymmetricKey(data: keyHash)

        guard let payloadData = try? JSONEncoder().encode(payload) else { return nil }

        guard let sealedBox = try? AES.GCM.seal(payloadData, using: symmetricKey) else { return nil }

        // Format: nonce (12 bytes) + ciphertext + tag (16 bytes) — matches CryptoSwift GCM combined mode
        guard let combined = sealedBox.combined else { return nil }
        return combined.base64EncodedString()
    }

    // MARK: - CryptoKit P256 JWT Signing

    private static func signJWT(keyId: String, teamId: String, apnsKey: String) -> String? {
        // Extract raw key data from PEM
        let lines = apnsKey.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        let base64Key = lines.joined()
        guard let keyData = Data(base64Encoded: base64Key) else { return nil }

        guard let privateKey = try? P256.Signing.PrivateKey(derRepresentation: keyData) else { return nil }

        // Header
        let header = #"{"alg":"ES256","kid":"\#(keyId)"}"#
        // Claims
        let claims = #"{"iss":"\#(teamId)","iat":\#(Int(Date().timeIntervalSince1970))}"#

        guard let headerData = header.data(using: .utf8),
              let claimsData = claims.data(using: .utf8)
        else { return nil }

        let headerB64 = base64URLEncode(headerData)
        let claimsB64 = base64URLEncode(claimsData)
        let signingInput = "\(headerB64).\(claimsB64)"

        guard let signingData = signingInput.data(using: .utf8),
              let signature = try? privateKey.signature(for: signingData)
        else { return nil }

        let signatureB64 = base64URLEncode(signature.rawRepresentation)
        return "\(signingInput).\(signatureB64)"
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Nightscout Treatments POST

    private static func postNightscoutTreatment(body: [String: Any], config: WatchConfig, completion: @escaping (Bool, String?) -> Void) {
        guard config.nsWriteAuth else {
            completion(false, "Nightscout write auth not enabled")
            return
        }

        // First get JWT token from status endpoint
        fetchNightscoutJWT(config: config) { jwt in
            guard let jwt = jwt else {
                completion(false, "Failed to get Nightscout auth token")
                return
            }

            var components = URLComponents(string: config.nsURL)
            components?.path = "/api/v1/treatments.json"

            guard let url = components?.url else {
                completion(false, "Invalid Nightscout URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                        return
                    }
                    if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                        completion(true, nil)
                    } else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        completion(false, "Nightscout error: \(code)")
                    }
                }
            }.resume()
        }
    }

    private static func fetchNightscoutJWT(config: WatchConfig, completion: @escaping (String?) -> Void) {
        var components = URLComponents(string: config.nsURL)
        components?.path = "/api/v1/status.json"
        if !config.nsToken.isEmpty {
            components?.queryItems = [URLQueryItem(name: "token", value: config.nsToken)]
        }

        guard let url = components?.url else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = json["token"] as? String
            else {
                // Fallback: use token directly as API secret hash
                completion(config.nsToken)
                return
            }
            completion(jwt)
        }.resume()
    }
}
