// LoopFollow
// PushNotificationManager.swift
// Created by Jonas Björkert.

import Foundation
import HealthKit
import SwiftJWT

class PushNotificationManager {
    private var deviceToken: String
    private var sharedSecret: String
    private var productionEnvironment: Bool
    private var apnsKey: String
    private var teamId: String
    private var keyId: String
    private var user: String
    private var bundleId: String

    init() {
        deviceToken = Storage.shared.deviceToken.value
        sharedSecret = Storage.shared.sharedSecret.value
        productionEnvironment = Storage.shared.productionEnvironment.value
        apnsKey = Storage.shared.apnsKey.value
        teamId = Storage.shared.teamId.value ?? ""
        keyId = Storage.shared.keyId.value
        user = Storage.shared.user.value
        bundleId = Storage.shared.bundleId.value
    }

    private func createReturnNotificationInfo() -> CommandPayload.ReturnNotificationInfo? {
        let loopFollowDeviceToken = Observable.shared.loopFollowDeviceToken.value

        guard !loopFollowDeviceToken.isEmpty else {
            return nil
        }

        guard let loopFollowTeamID = BuildDetails.default.teamID, !loopFollowTeamID.isEmpty else {
            LogManager.shared.log(category: .apns, message: "LoopFollow Team ID not found in BuildDetails.plist. Cannot create return notification info.")
            return nil
        }

        let teamIdsAreDifferent = loopFollowTeamID != teamId
        let keyIdForReturn: String
        let apnsKeyForReturn: String

        if teamIdsAreDifferent {
            keyIdForReturn = Storage.shared.returnKeyId.value
            apnsKeyForReturn = Storage.shared.returnApnsKey.value
        } else {
            keyIdForReturn = keyId
            apnsKeyForReturn = apnsKey
        }

        guard !keyIdForReturn.isEmpty, !apnsKeyForReturn.isEmpty else {
            LogManager.shared.log(category: .apns, message: "Missing required return APNS credentials. Check Remote Settings.")
            return nil
        }

        return CommandPayload.ReturnNotificationInfo(
            productionEnvironment: BuildDetails.default.isTestFlightBuild(),
            deviceToken: loopFollowDeviceToken,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            teamId: loopFollowTeamID,
            keyId: keyIdForReturn,
            apnsKey: apnsKeyForReturn
        )
    }

    func sendOverridePushNotification(override: ProfileManager.TrioOverride, completion: @escaping (Bool, String?) -> Void) {
        let payload = CommandPayload(
            user: user,
            commandType: .startOverride,
            timestamp: Date().timeIntervalSince1970,
            overrideName: override.name,
            returnNotification: createReturnNotificationInfo()
        )
        sendEncryptedCommand(payload: payload, completion: completion)
    }

    func sendCancelOverridePushNotification(completion: @escaping (Bool, String?) -> Void) {
        let payload = CommandPayload(
            user: user,
            commandType: .cancelOverride,
            timestamp: Date().timeIntervalSince1970,
            overrideName: nil,
            returnNotification: createReturnNotificationInfo()
        )
        sendEncryptedCommand(payload: payload, completion: completion)
    }

    func sendBolusPushNotification(bolusAmount: HKQuantity, completion: @escaping (Bool, String?) -> Void) {
        let bolusAmountDecimal = Decimal(bolusAmount.doubleValue(for: .internationalUnit()))
        let payload = CommandPayload(
            user: user,
            commandType: .bolus,
            timestamp: Date().timeIntervalSince1970,
            bolusAmount: bolusAmountDecimal,
            returnNotification: createReturnNotificationInfo()
        )
        sendEncryptedCommand(payload: payload, completion: completion)
    }

    func sendTempTargetPushNotification(target: HKQuantity, duration: HKQuantity, completion: @escaping (Bool, String?) -> Void) {
        let targetValue = Int(target.doubleValue(for: HKUnit.milligramsPerDeciliter))
        let durationValue = Int(duration.doubleValue(for: HKUnit.minute()))
        let payload = CommandPayload(
            user: user,
            commandType: .tempTarget,
            timestamp: Date().timeIntervalSince1970,
            target: targetValue,
            duration: durationValue,
            returnNotification: createReturnNotificationInfo()
        )
        sendEncryptedCommand(payload: payload, completion: completion)
    }

    func sendCancelTempTargetPushNotification(completion: @escaping (Bool, String?) -> Void) {
        let payload = CommandPayload(
            user: user,
            commandType: .cancelTempTarget,
            timestamp: Date().timeIntervalSince1970,
            returnNotification: createReturnNotificationInfo()
        )
        sendEncryptedCommand(payload: payload, completion: completion)
    }

    func sendMealPushNotification(
        carbs: HKQuantity,
        protein: HKQuantity,
        fat: HKQuantity,
        bolusAmount: HKQuantity,
        scheduledTime: Date?,
        completion: @escaping (Bool, String?) -> Void
    ) {
        func convertToOptionalInt(_ quantity: HKQuantity) -> Int? {
            let valueInGrams = quantity.doubleValue(for: .gram())
            return valueInGrams > 0 ? Int(valueInGrams) : nil
        }
        func convertToOptionalDecimal(_ quantity: HKQuantity?) -> Decimal? {
            guard let quantity = quantity else { return nil }
            let value = quantity.doubleValue(for: .internationalUnit())
            return value > 0 ? Decimal(value) : nil
        }
        let carbsValue = convertToOptionalInt(carbs)
        let proteinValue = convertToOptionalInt(protein)
        let fatValue = convertToOptionalInt(fat)
        let scheduledTimeInterval: TimeInterval? = scheduledTime?.timeIntervalSince1970
        let bolusAmountValue = convertToOptionalDecimal(bolusAmount)
        guard carbsValue != nil || proteinValue != nil || fatValue != nil else {
            completion(false, "No nutrient data provided. At least one of carbs, fat, or protein must be greater than 0.")
            return
        }
        let payload = CommandPayload(
            user: user,
            commandType: .meal,
            timestamp: Date().timeIntervalSince1970,
            bolusAmount: bolusAmountValue,
            carbs: carbsValue,
            protein: proteinValue,
            fat: fatValue,
            scheduledTime: scheduledTimeInterval,
            returnNotification: createReturnNotificationInfo()
        )
        sendEncryptedCommand(payload: payload, completion: completion)
    }

    private func validateCredentials() -> [String]? {
        var errors = [String]()
        let keyIdPattern = "^[A-Z0-9]{10}$"
        if !matchesRegex(keyId, pattern: keyIdPattern) {
            errors.append("APNS Key ID (\(keyId)) must be 10 uppercase alphanumeric characters.")
        }
        let teamIdPattern = "^[A-Z0-9]{10}$"
        if !matchesRegex(teamId, pattern: teamIdPattern) {
            errors.append("Team ID (\(teamId)) must be 10 uppercase alphanumeric characters.")
        }
        if !apnsKey.contains("-----BEGIN PRIVATE KEY-----") || !apnsKey.contains("-----END PRIVATE KEY-----") {
            errors.append("APNS Key must be a valid PEM-formatted private key.")
        } else {
            if let keyData = extractKeyData(from: apnsKey) {
                if Data(base64Encoded: keyData) == nil {
                    errors.append("APNS Key contains invalid Base64 key data.")
                }
            } else {
                errors.append("APNS Key has invalid formatting.")
            }
        }
        return errors.isEmpty ? nil : errors
    }

    private func matchesRegex(_ text: String, pattern: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex?.firstMatch(in: text, options: [], range: range) != nil
    }

    private func extractKeyData(from pemString: String) -> String? {
        let lines = pemString.components(separatedBy: "\n")
        guard let startIndex = lines.firstIndex(of: "-----BEGIN PRIVATE KEY-----"),
              let endIndex = lines.firstIndex(of: "-----END PRIVATE KEY-----"),
              startIndex < endIndex
        else {
            return nil
        }
        let keyLines = lines[(startIndex + 1) ..< endIndex]
        return keyLines.joined()
    }

    private func sendEncryptedCommand(payload: CommandPayload, completion: @escaping (Bool, String?) -> Void) {
        var missingFields = [String]()
        if sharedSecret.isEmpty { missingFields.append("sharedSecret") }
        if apnsKey.isEmpty { missingFields.append("apnsKey") }
        if keyId.isEmpty { missingFields.append("keyId") }
        if user.isEmpty { missingFields.append("user") }
        if deviceToken.isEmpty { missingFields.append("deviceToken") }
        if bundleId.isEmpty { missingFields.append("bundleId") }
        if teamId.isEmpty { missingFields.append("teamId") }

        if !missingFields.isEmpty {
            let errorMessage = "Missing required fields for command: \(missingFields.joined(separator: ", "))"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        if let validationErrors = validateCredentials() {
            let errorMessage = "Credential validation failed: \(validationErrors.joined(separator: ", "))"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        guard let url = constructAPNsURL() else {
            let errorMessage = "Failed to construct APNs URL"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: keyId, teamId: teamId, apnsKey: apnsKey) else {
            let errorMessage = "Failed to generate JWT, please check that the token is correct."
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        do {
            guard let messenger = SecureMessenger(sharedSecret: sharedSecret) else {
                let errorMessage = "Failed to initialize security module. Check shared secret."
                LogManager.shared.log(category: .apns, message: errorMessage)
                completion(false, errorMessage)
                return
            }

            let encryptedDataString = try messenger.encrypt(payload)
            let finalMessage = EncryptedPushMessage(encryptedData: encryptedDataString)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.setValue("10", forHTTPHeaderField: "apns-priority")
            request.setValue("0", forHTTPHeaderField: "apns-expiration")
            request.setValue(bundleId, forHTTPHeaderField: "apns-topic")
            request.setValue("background", forHTTPHeaderField: "apns-push-type")

            request.httpBody = try JSONEncoder().encode(finalMessage)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    let errorMessage = "Failed to send push notification: \(error.localizedDescription)"
                    LogManager.shared.log(category: .apns, message: errorMessage)
                    completion(false, errorMessage)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Push notification sent.")
                    print("Status code: \(httpResponse.statusCode)")

                    var responseBodyMessage = ""
                    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseBody)")
                        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let reason = json["reason"] as? String
                        {
                            responseBodyMessage = reason
                        }
                    }

                    switch httpResponse.statusCode {
                    case 200:
                        completion(true, nil)
                    case 400:
                        completion(false, "Bad request. The request was invalid or malformed. \(responseBodyMessage)")
                    case 403:
                        completion(false, "Authentication error. Check your certificate or authentication token. \(responseBodyMessage)")
                    case 404:
                        completion(false, "Invalid request: The :path value was incorrect. \(responseBodyMessage)")
                    case 405:
                        completion(false, "Invalid request: Only POST requests are supported. \(responseBodyMessage)")
                    case 410:
                        completion(false, "The device token is no longer active for the topic. \(responseBodyMessage)")
                    case 413:
                        completion(false, "Payload too large. The notification payload exceeded the size limit. \(responseBodyMessage)")
                    case 429:
                        completion(false, "Too many requests. \(responseBodyMessage)")
                    case 500:
                        completion(false, "Internal server error at APNs. \(responseBodyMessage)")
                    case 503:
                        completion(false, "Service unavailable. The server is temporarily unavailable. Try again later. \(responseBodyMessage)")
                    default:
                        completion(false, "Unexpected status code: \(httpResponse.statusCode). \(responseBodyMessage)")
                    }
                } else {
                    completion(false, "Failed to get a valid HTTP response.")
                }
            }
            task.resume()

        } catch {
            let errorMessage = "Failed to encode or encrypt push message: \(error.localizedDescription)"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
        }
    }

    private func constructAPNsURL() -> URL? {
        let host = productionEnvironment ? "api.push.apple.com" : "api.sandbox.push.apple.com"
        let urlString = "https://\(host)/3/device/\(deviceToken)"
        return URL(string: urlString)
    }
}
