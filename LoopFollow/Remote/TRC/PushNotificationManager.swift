// LoopFollow
// PushNotificationManager.swift
// Created by Jonas Björkert on 2024-09-17.

import Foundation
import HealthKit
import SwiftJWT

struct APNsJWTClaims: Claims {
    let iss: String
    let iat: Date
}

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

    func sendOverridePushNotification(override: ProfileManager.TrioOverride, completion: @escaping (Bool, String?) -> Void) {
        let message = PushMessage(
            user: user,
            commandType: .startOverride,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970,
            overrideName: override.name
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendCancelOverridePushNotification(completion: @escaping (Bool, String?) -> Void) {
        let message = PushMessage(
            user: user,
            commandType: .cancelOverride,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970,
            overrideName: nil
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendBolusPushNotification(bolusAmount: HKQuantity, completion: @escaping (Bool, String?) -> Void) {
        let bolusAmount = Decimal(bolusAmount.doubleValue(for: .internationalUnit()))

        let message = PushMessage(
            user: user,
            commandType: .bolus,
            bolusAmount: bolusAmount,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendTempTargetPushNotification(target: HKQuantity, duration: HKQuantity, completion: @escaping (Bool, String?) -> Void) {
        let targetValue = Int(target.doubleValue(for: HKUnit.milligramsPerDeciliter))
        let durationValue = Int(duration.doubleValue(for: HKUnit.minute()))

        let message = PushMessage(
            user: user,
            commandType: .tempTarget,
            bolusAmount: nil,
            target: targetValue,
            duration: durationValue,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendCancelTempTargetPushNotification(completion: @escaping (Bool, String?) -> Void) {
        let message = PushMessage(
            user: user,
            commandType: .cancelTempTarget,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
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

        let message = PushMessage(
            user: user,
            commandType: .meal,
            bolusAmount: bolusAmountValue,
            carbs: carbsValue,
            protein: proteinValue,
            fat: fatValue,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970,
            scheduledTime: scheduledTimeInterval
        )

        sendPushNotification(message: message, completion: completion)
    }

    private func validateCredentials() -> [String]? {
        var errors = [String]()

        // Validate keyId (should be 10 alphanumeric characters)
        let keyIdPattern = "^[A-Z0-9]{10}$"
        if !matchesRegex(keyId, pattern: keyIdPattern) {
            errors.append("APNS Key ID (\(keyId)) must be 10 uppercase alphanumeric characters.")
        }

        // Validate teamId (should be 10 alphanumeric characters)
        let teamIdPattern = "^[A-Z0-9]{10}$"
        if !matchesRegex(teamId, pattern: teamIdPattern) {
            errors.append("Team ID (\(teamId)) must be 10 uppercase alphanumeric characters.")
        }

        // Validate apnsKey (should contain the BEGIN and END PRIVATE KEY markers)
        if !apnsKey.contains("-----BEGIN PRIVATE KEY-----") || !apnsKey.contains("-----END PRIVATE KEY-----") {
            errors.append("APNS Key must be a valid PEM-formatted private key.")
        } else {
            // Validate that the key data between the markers is valid Base64
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

    private func sendPushNotification(message: PushMessage, completion: @escaping (Bool, String?) -> Void) {
        print("Push message to send: \(message)")

        var missingFields = [String]()
        if sharedSecret.isEmpty { missingFields.append("sharedSecret") }
        if apnsKey.isEmpty { missingFields.append("token") }
        if keyId.isEmpty { missingFields.append("keyId") }
        if user.isEmpty { missingFields.append("user") }

        if !missingFields.isEmpty {
            let errorMessage = "Missing required fields, check your remote settings: \(missingFields.joined(separator: ", "))"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        if deviceToken.isEmpty { missingFields.append("deviceToken") }
        if bundleId.isEmpty { missingFields.append("bundleId") }
        if teamId.isEmpty { missingFields.append("teamId") }

        if !missingFields.isEmpty {
            let errorMessage = "Missing required data, verify that you are using the latest version of Trio: \(missingFields.joined(separator: ", "))"
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

        guard let jwt = getOrGenerateJWT() else {
            let errorMessage = "Failed to generate JWT, please check that the token is correct."
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue("0", forHTTPHeaderField: "apns-expiration")
        request.setValue(bundleId, forHTTPHeaderField: "apns-topic")
        request.setValue("background", forHTTPHeaderField: "apns-push-type")

        do {
            let jsonData = try JSONEncoder().encode(message)
            request.httpBody = jsonData

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

                    print("Response headers:")
                    for (key, value) in httpResponse.allHeaderFields {
                        print("\(key): \(value)")
                    }

                    var responseBodyMessage = ""
                    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseBody)")

                        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let reason = json["reason"] as? String
                        {
                            responseBodyMessage = reason
                        }
                    } else {
                        print("No response body")
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
            let errorMessage = "Failed to encode push message: \(error.localizedDescription)"
            print(errorMessage)
            completion(false, errorMessage)
        }
    }

    private func constructAPNsURL() -> URL? {
        let host = productionEnvironment ? "api.push.apple.com" : "api.sandbox.push.apple.com"
        let urlString = "https://\(host)/3/device/\(deviceToken)"
        return URL(string: urlString)
    }

    private func getOrGenerateJWT() -> String? {
        if let cachedJWT = Storage.shared.cachedJWT.value, let expirationDate = Storage.shared.jwtExpirationDate.value {
            if Date() < expirationDate {
                return cachedJWT
            }
        }

        let header = Header(kid: keyId)
        let claims = APNsJWTClaims(iss: teamId, iat: Date())

        var jwt = JWT(header: header, claims: claims)

        do {
            let privateKey = Data(apnsKey.utf8)
            let jwtSigner = JWTSigner.es256(privateKey: privateKey)
            let signedJWT = try jwt.sign(using: jwtSigner)

            Storage.shared.cachedJWT.value = signedJWT
            Storage.shared.jwtExpirationDate.value = Date().addingTimeInterval(3600)

            return signedJWT
        } catch {
            print("Failed to sign JWT: \(error.localizedDescription)")
            return nil
        }
    }
}
