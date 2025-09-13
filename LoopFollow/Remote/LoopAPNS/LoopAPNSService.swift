// LoopFollow
// LoopAPNSService.swift

import CryptoKit
import Foundation
import HealthKit
import SwiftJWT

class LoopAPNSService {
    private let storage = Storage.shared

    enum LoopAPNSError: Error, LocalizedError {
        case invalidConfiguration
        case jwtError
        case networkError
        case invalidResponse
        case noDeviceToken
        case noBundleIdentifier
        case unauthorized
        case deviceTokenNotConfigured
        case bundleIdentifierNotConfigured
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Loop APNS Configuration not valid"
            case .jwtError:
                return "Failed generating JWT token, check APNS Key ID, APNS Key and Team ID"
            case .networkError:
                return "Network error occurred"
            case .invalidResponse:
                return "Invalid response from server"
            case .noDeviceToken:
                return "No device token found in profile"
            case .noBundleIdentifier:
                return "No bundle identifier found in profile"
            case .unauthorized:
                return "Unauthorized - check your API secret"
            case .deviceTokenNotConfigured:
                return "Device token not configured"
            case .bundleIdentifierNotConfigured:
                return "Bundle identifier not configured"
            case .rateLimited:
                return "Too many requests - please wait a few minutes before trying again"
            }
        }
    }

    /// Validates the Loop APNS setup by checking all required fields
    /// - Returns: True if setup is valid, false otherwise
    func validateSetup() -> Bool {
        let hasKeyId = !storage.keyId.value.isEmpty
        let hasAPNSKey = !storage.apnsKey.value.isEmpty
        let hasQrCode = !storage.loopAPNSQrCodeURL.value.isEmpty
        let hasDeviceToken = !Storage.shared.deviceToken.value.isEmpty
        let hasBundleIdentifier = !Storage.shared.bundleId.value.isEmpty

        // For initial setup, we don't require device token and bundle identifier
        // These will be fetched when the user clicks "Refresh Device Token"
        let hasBasicSetup = hasKeyId && hasAPNSKey && hasQrCode

        // For full validation (after device token is fetched), check everything
        let hasFullSetup = hasBasicSetup && hasDeviceToken && hasBundleIdentifier

        return hasFullSetup
    }

    /// Sends carbs via APNS push notification
    /// - Parameters:
    ///   - payload: The carbs payload to send
    ///   - completion: Completion handler with success status and error message
    func sendCarbsViaAPNS(payload: LoopAPNSPayload, completion: @escaping (Bool, String?) -> Void) {
        guard validateSetup() else {
            let errorMessage = "Loop APNS Configuration not valid"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        let deviceToken = Storage.shared.deviceToken.value
        let bundleIdentifier = Storage.shared.bundleId.value
        let keyId = storage.keyId.value
        let apnsKey = storage.apnsKey.value

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        // Create the complete notification payload (matching Nightscout's exact format)
        // Based on Nightscout's loop.js implementation
        let carbsAmount = payload.carbsAmount ?? 0.0
        let absorptionTime = payload.absorptionTime ?? 3.0
        let startTime = payload.consumedDate ?? now
        let finalPayload = [
            "carbs-entry": carbsAmount,
            "absorption-time": absorptionTime,
            "otp": String(payload.otp),
            "remote-address": "LoopFollow",
            "notes": "Sent via LoopFollow APNS",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "start-time": formatDateForAPNS(startTime),
            "alert": "Remote Carbs Entry: \(String(format: "%.1f", carbsAmount)) grams\nAbsorption Time: \(String(format: "%.1f", absorptionTime)) hours",
        ] as [String: Any]

        // Log carbs entry attempt
        LogManager.shared.log(category: .apns, message: "Sending carbs: \(String(format: "%.1f", carbsAmount))g, absorption: \(String(format: "%.1f", absorptionTime))h")

        sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: keyId,
            apnsKey: apnsKey,
            payload: finalPayload,
            completion: completion
        )
    }

    /// Sends bolus via APNS push notification
    /// - Parameters:
    ///   - payload: The bolus payload to send
    ///   - completion: Completion handler with success status and error message
    func sendBolusViaAPNS(payload: LoopAPNSPayload, completion: @escaping (Bool, String?) -> Void) {
        guard validateSetup() else {
            let errorMessage = "Loop APNS Configuration not valid"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        let deviceToken = Storage.shared.deviceToken.value
        let bundleIdentifier = Storage.shared.bundleId.value
        let keyId = storage.keyId.value
        let apnsKey = storage.apnsKey.value

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        // Create the complete notification payload (matching Nightscout's exact format)
        // Based on Nightscout's loop.js implementation
        let bolusAmount = payload.bolusAmount ?? 0.0
        let finalPayload = [
            "bolus-entry": bolusAmount,
            "otp": String(payload.otp),
            "remote-address": "LoopFollow",
            "notes": "Sent via LoopFollow APNS",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": "Remote Bolus Entry: \(String(format: "%.2f", bolusAmount)) U",
        ] as [String: Any]

        // Log bolus entry attempt
        LogManager.shared.log(category: .apns, message: "Sending bolus: \(String(format: "%.2f", bolusAmount))U")

        sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: keyId,
            apnsKey: apnsKey,
            payload: finalPayload,
            completion: completion
        )
    }

    /// Validates APNS credentials similar to PushNotificationManager
    /// - Returns: Array of validation error messages, or nil if valid
    private func validateCredentials() -> [String]? {
        var errors = [String]()

        let keyId = storage.keyId.value
        let teamId = Storage.shared.teamId.value ?? ""
        let apnsKey = storage.apnsKey.value

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

    /// Helper method to match regex patterns
    /// - Parameters:
    ///   - text: Text to match
    ///   - pattern: Regex pattern
    /// - Returns: True if pattern matches
    private func matchesRegex(_ text: String, pattern: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        return regex?.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Provides environment-specific guidance for APNS configuration
    /// - Returns: String with guidance based on build configuration
    private func getEnvironmentGuidance() -> String {
        #if DEBUG
            let buildType = "Xcode"
            let recommendedEnvironment = "Development"
            let environmentSetting = "Production Environment: OFF"
        #else
            let buildType = "Browser/TestFlight"
            let recommendedEnvironment = "Production"
            let environmentSetting = "Production Environment: ON"
        #endif

        let currentEnvironment = storage.productionEnvironment.value ? "Production" : "Development"

        return """
        Environment Configuration Help:

        Build Type: \(buildType)
        Current Setting: \(currentEnvironment)
        Recommended Setting: \(recommendedEnvironment)

        Please check your Loop Remote control settings:
        • If you built with Xcode: Set "\(environmentSetting)"
        • If you built with Browser/TestFlight: Set "Production Environment: ON"
        """
    }

    /// Sends an APNS notification
    /// - Parameters:
    ///   - deviceToken: The device token to send to
    ///   - bundleIdentifier: The bundle identifier
    ///   - keyId: The APNS key ID
    ///   - apnsKey: The APNS key
    ///   - payload: The notification payload
    ///   - completion: Completion handler with success status and error message
    private func sendAPNSNotification(
        deviceToken: String,
        bundleIdentifier: String,
        keyId: String,
        apnsKey: String,
        payload: [String: Any],
        completion: @escaping (Bool, String?) -> Void
    ) {
        // Validate credentials first
        if let validationErrors = validateCredentials() {
            let errorMessage = "Credential validation failed: \(validationErrors.joined(separator: ", "))"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        // Create JWT token for APNS authentication
        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: keyId, teamId: Storage.shared.teamId.value ?? "", apnsKey: apnsKey) else {
            let errorMessage = "Failed to generate JWT, please check that the APNS Key ID, APNS Key and Team ID are correct."
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        // Determine APNS environment
        let isProduction = storage.productionEnvironment.value
        let apnsURL = isProduction ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com"
        guard let requestURL = URL(string: "\(apnsURL)/3/device/\(deviceToken)") else {
            let errorMessage = "Failed to construct APNs URL"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "apns-topic")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority") // High priority

        // Validate bundle identifier format
        if !bundleIdentifier.contains(".") {
            LogManager.shared.log(category: .apns, message: "Warning: Bundle identifier may be in wrong format: \(bundleIdentifier)")
        }

        // Create the proper APNS payload structure (matching @parse/node-apn format)
        var apnsPayload: [String: Any] = [
            "aps": [
                "alert": payload["alert"] as? String ?? "",
                "content-available": 1,
                "interruption-level": "time-sensitive",
            ],
        ]

        // Add all the custom payload fields (excluding APNS-specific fields)
        for (key, value) in payload {
            if key != "alert", key != "content-available", key != "interruption-level" {
                apnsPayload[key] = value
            }
        }

        // Remove nil values to clean up the payload
        let cleanPayload = apnsPayload.compactMapValues { $0 }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: cleanPayload)

            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    let errorMessage = "Failed to send push notification: \(error.localizedDescription)"
                    LogManager.shared.log(category: .apns, message: errorMessage)
                    completion(false, errorMessage)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    var responseBodyMessage = ""
                    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                           let reason = json["reason"] as? String
                        {
                            responseBodyMessage = reason
                        }
                    }

                    switch httpResponse.statusCode {
                    case 200:
                        LogManager.shared.log(category: .apns, message: "APNS notification sent successfully")
                        completion(true, nil)
                    case 400:
                        let environmentGuidance = self.getEnvironmentGuidance()
                        let errorMessage = "Bad request. The request was invalid or malformed. \(responseBodyMessage)\n\n\(environmentGuidance)"
                        LogManager.shared.log(category: .apns, message: "APNS error 400: \(responseBodyMessage) - Check device token and environment settings")
                        completion(false, errorMessage)
                    case 403:
                        let errorMessage = "Authentication error. Check your certificate or authentication token. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 403: \(responseBodyMessage) - Check APNS key permissions for bundle ID")
                        completion(false, errorMessage)
                    case 404:
                        let errorMessage = "Invalid request: The :path value was incorrect. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 404: \(responseBodyMessage)")
                        completion(false, errorMessage)
                    case 405:
                        let errorMessage = "Invalid request: Only POST requests are supported. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 405: \(responseBodyMessage)")
                        completion(false, errorMessage)
                    case 410:
                        let errorMessage = "The device token is no longer active for the topic. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 410: Device token is invalid or expired")
                        completion(false, errorMessage)
                    case 413:
                        let errorMessage = "Payload too large. The notification payload exceeded the size limit. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 413: \(responseBodyMessage)")
                        completion(false, errorMessage)
                    case 429:
                        let errorMessage = "Too many requests. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 429: Rate limited - wait before retrying")
                        completion(false, errorMessage)
                    case 500:
                        let errorMessage = "Internal server error at APNs. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 500: \(responseBodyMessage)")
                        completion(false, errorMessage)
                    case 503:
                        let errorMessage = "Service unavailable. The server is temporarily unavailable. Try again later. \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error 503: \(responseBodyMessage)")
                        completion(false, errorMessage)
                    default:
                        let errorMessage = "Unexpected status code: \(httpResponse.statusCode). \(responseBodyMessage)"
                        LogManager.shared.log(category: .apns, message: "APNS error \(httpResponse.statusCode): \(responseBodyMessage)")
                        completion(false, errorMessage)
                    }
                } else {
                    let errorMessage = "Failed to get a valid HTTP response."
                    LogManager.shared.log(category: .apns, message: errorMessage)
                    completion(false, errorMessage)
                }
            }
            task.resume()

        } catch {
            let errorMessage = "Failed to serialize APNS payload: \(error.localizedDescription)"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
        }
    }

    /// Validates and fixes APNS key format if needed
    /// - Parameter key: The APNS key to validate and fix
    /// - Returns: The fixed APNS key
    func validateAndFixAPNSKey(_ key: String) -> String {
        // Normalize: replace all literal \n with real newlines
        var fixedKey = key.replacingOccurrences(of: "\\n", with: "\n")

        // Strip leading/trailing quotes
        fixedKey = fixedKey.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        // Check if the key has proper line breaks
        if !fixedKey.contains("\n") {
            LogManager.shared.log(category: .apns, message: "APNS Key missing line breaks, attempting to fix format")

            // Try to add line breaks if the key is all on one line
            if fixedKey.contains("-----BEGIN PRIVATE KEY-----") && fixedKey.contains("-----END PRIVATE KEY-----") {
                // Find the positions of the headers
                if let beginRange = fixedKey.range(of: "-----BEGIN PRIVATE KEY-----"),
                   let endRange = fixedKey.range(of: "-----END PRIVATE KEY-----")
                {
                    let beginIndex = fixedKey.index(beginRange.upperBound, offsetBy: 0)
                    let endIndex = endRange.lowerBound

                    if beginIndex < endIndex {
                        let header = String(fixedKey[..<beginIndex])
                        let keyData = String(fixedKey[beginIndex ..< endIndex])
                        let footer = String(fixedKey[endIndex...])

                        // Clean up the key data - remove any whitespace and split into 64-character lines
                        let cleanKeyData = keyData.replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "\t", with: "")
                            .replacingOccurrences(of: "\n", with: "")
                            .replacingOccurrences(of: "\r", with: "")

                        // Validate the key data length (should be 44 characters for P-256)
                        LogManager.shared.log(category: .apns, message: "Key data validation - Length: \(cleanKeyData.count) characters")
                        if cleanKeyData.count != 44 {
                            LogManager.shared.log(category: .apns, message: "WARNING: Key data length is \(cleanKeyData.count), expected 44 for P-256 private key")
                        }

                        // Validate base64 format
                        if Data(base64Encoded: cleanKeyData) == nil {
                            LogManager.shared.log(category: .apns, message: "WARNING: Key data is not valid base64")
                        }

                        // Split into 64-character lines (standard PEM format)
                        var formattedKeyData = ""
                        var currentLine = ""
                        for char in cleanKeyData {
                            currentLine.append(char)
                            if currentLine.count == 64 {
                                formattedKeyData += currentLine + "\n"
                                currentLine = ""
                            }
                        }
                        // Add any remaining characters
                        if !currentLine.isEmpty {
                            formattedKeyData += currentLine
                        }

                        fixedKey = "\(header)\n\(formattedKeyData)\n\(footer)"

                        LogManager.shared.log(category: .apns, message: "APNS Key format fixed - added proper line breaks")
                        LogManager.shared.log(category: .apns, message: "Key data length: \(cleanKeyData.count) characters")
                        LogManager.shared.log(category: .apns, message: "Formatted key lines: \(formattedKeyData.components(separatedBy: "\n").count)")
                    }
                }
            }
        } else {
            // Key already has line breaks, but let's ensure proper formatting
            let lines = fixedKey.components(separatedBy: .newlines)
            var cleanedLines: [String] = []

            for line in lines {
                let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedLine.isEmpty {
                    cleanedLines.append(cleanedLine)
                }
            }

            // Reconstruct with proper formatting
            if cleanedLines.count > 2 {
                let header = cleanedLines[0]
                let footer = cleanedLines[cleanedLines.count - 1]
                let keyLines = Array(cleanedLines[1 ..< (cleanedLines.count - 1)])

                // Combine all key data lines and validate
                let combinedKeyData = keyLines.joined()
                LogManager.shared.log(category: .apns, message: "Combined key data length: \(combinedKeyData.count) characters")

                // Validate the key data length (should be 44 characters for P-256)
                if combinedKeyData.count != 44 {
                    LogManager.shared.log(category: .apns, message: "WARNING: Combined key data length is \(combinedKeyData.count), expected 44 for P-256 private key")
                }

                // Validate base64 format
                if Data(base64Encoded: combinedKeyData) == nil {
                    LogManager.shared.log(category: .apns, message: "WARNING: Combined key data is not valid base64")
                }

                // Ensure key lines are properly formatted (64 characters each)
                var formattedKeyLines: [String] = []
                var currentLine = ""

                for line in keyLines {
                    let cleanLine = line.replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "\t", with: "")

                    for char in cleanLine {
                        currentLine.append(char)
                        if currentLine.count == 64 {
                            formattedKeyLines.append(currentLine)
                            currentLine = ""
                        }
                    }
                }

                // Add any remaining characters
                if !currentLine.isEmpty {
                    formattedKeyLines.append(currentLine)
                }

                fixedKey = "\(header)\n\(formattedKeyLines.joined(separator: "\n"))\n\(footer)"

                LogManager.shared.log(category: .apns, message: "APNS Key reformatted - cleaned up existing line breaks")
            }
        }

        return fixedKey
    }

    /// Extracts key data from PEM format
    /// - Parameter pemString: The PEM formatted private key
    /// - Returns: The extracted key data string
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

    // MARK: - Date Formatting Helper

    /// Creates a properly formatted ISO8601 date string with milliseconds (matching Nightscout's format)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string like "2022-12-24T21:34:02.090Z"
    private func formatDateForAPNS(_ date: Date) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.string(from: date)
    }

    // MARK: - Override Methods

    func sendOverrideNotification(presetName: String, duration: TimeInterval? = nil, completion: @escaping (Bool, String?) -> Void) {
        let deviceToken = Storage.shared.deviceToken.value
        guard !deviceToken.isEmpty else {
            let errorMessage = "Device token not configured"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        let bundleIdentifier = Storage.shared.bundleId.value
        guard !bundleIdentifier.isEmpty else {
            let errorMessage = "Bundle identifier not configured"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        // Create alert text (matching Nightscout's format)
        var alertText = "\(presetName) Temporary Override"
        if let duration = duration, duration > 0 {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                alertText += " (\(hours)h \(minutes)m)"
            } else {
                alertText += " (\(minutes)m)"
            }
        }

        var payload: [String: Any] = [
            "override-name": presetName,
            "remote-address": "LoopFollow",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": alertText,
        ]

        if let duration = duration, duration > 0 {
            payload["override-duration-minutes"] = Int(duration / 60)
        }

        // Send the notification using the existing APNS infrastructure
        sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: storage.keyId.value,
            apnsKey: storage.apnsKey.value,
            payload: payload,
            completion: completion
        )
    }

    func sendCancelOverrideNotification(completion: @escaping (Bool, String?) -> Void) {
        let deviceToken = Storage.shared.deviceToken.value
        guard !deviceToken.isEmpty else {
            let errorMessage = "Device token not configured"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        let bundleIdentifier = Storage.shared.bundleId.value
        guard !bundleIdentifier.isEmpty else {
            let errorMessage = "Bundle identifier not configured"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        let payload: [String: Any] = [
            "cancel-temporary-override": "true",
            "remote-address": "LoopFollow",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": "Cancel Temporary Override",
        ]

        // Send the notification using the existing APNS infrastructure
        sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: storage.keyId.value,
            apnsKey: storage.apnsKey.value,
            payload: payload,
            completion: completion
        )
    }
}
