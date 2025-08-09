// LoopFollow
// LoopAPNSService.swift
// Created by Daniel Mini Johansson.

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

    private func createReturnNotificationInfo() -> [String: Any]? {
        let loopFollowDeviceToken = Observable.shared.loopFollowDeviceToken.value
        guard !loopFollowDeviceToken.isEmpty else { return nil }

        // Get LoopFollow's own Team ID from BuildDetails.
        guard let loopFollowTeamID = BuildDetails.default.teamID, !loopFollowTeamID.isEmpty else {
            LogManager.shared.log(category: .apns, message: "LoopFollow Team ID not found in BuildDetails.plist. Cannot create return notification info.")
            return nil
        }

        // Get the target Loop app's Team ID from storage.
        let targetTeamId = storage.teamId.value ?? ""
        let teamIdsAreDifferent = loopFollowTeamID != targetTeamId

        let keyIdForReturn: String
        let apnsKeyForReturn: String

        if teamIdsAreDifferent {
            // Team IDs differ, use the separate return credentials.
            keyIdForReturn = storage.returnKeyId.value
            apnsKeyForReturn = storage.returnApnsKey.value
        } else {
            // Team IDs are the same, use the primary credentials.
            keyIdForReturn = storage.keyId.value
            apnsKeyForReturn = storage.apnsKey.value
        }

        // Ensure we have the necessary credentials.
        guard !keyIdForReturn.isEmpty, !apnsKeyForReturn.isEmpty else {
            LogManager.shared.log(category: .apns, message: "Missing required return APNS credentials. Check Remote Settings.")
            return nil
        }

        let returnInfo: [String: Any] = [
            "production_environment": BuildDetails.default.isTestFlightBuild(),
            "device_token": loopFollowDeviceToken,
            "bundle_id": Bundle.main.bundleIdentifier ?? "",
            "team_id": loopFollowTeamID,
            "key_id": keyIdForReturn,
            "apns_key": apnsKeyForReturn,
        ]

        return returnInfo
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
    /// - Parameter payload: The carbs payload to send
    /// - Returns: True if successful, false otherwise
    func sendCarbsViaAPNS(payload: LoopAPNSPayload) async throws -> Bool {
        guard validateSetup() else {
            throw LoopAPNSError.invalidConfiguration
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
        var finalPayload = [
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

        /* Let's wait with this until we have an encryption solution for LRC
        if let returnInfo = createReturnNotificationInfo() {
            finalPayload["return_notification"] = returnInfo
        }
        */

        // Log the exact carbs amount for debugging precision issues
        LogManager.shared.log(category: .apns, message: "Carbs amount - Raw: \(payload.carbsAmount ?? 0.0), Formatted: \(String(format: "%.1f", carbsAmount)), JSON: \(carbsAmount)")
        LogManager.shared.log(category: .apns, message: "Absorption time - Raw: \(payload.absorptionTime ?? 3.0), Formatted: \(String(format: "%.1f", absorptionTime)), JSON: \(absorptionTime)")

        // Log the final payload for debugging
        if let payloadData = try? JSONSerialization.data(withJSONObject: finalPayload),
           let payloadString = String(data: payloadData, encoding: .utf8)
        {
            LogManager.shared.log(category: .apns, message: "Final payload being sent: \(payloadString)")
        }
        return try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: keyId,
            apnsKey: apnsKey,
            payload: finalPayload
        )
    }

    /// Sends bolus via APNS push notification
    /// - Parameter payload: The bolus payload to send
    /// - Returns: True if successful, false otherwise
    func sendBolusViaAPNS(payload: LoopAPNSPayload) async throws -> Bool {
        guard validateSetup() else {
            throw LoopAPNSError.invalidConfiguration
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
        var finalPayload = [
            "bolus-entry": bolusAmount,
            "otp": String(payload.otp),
            "remote-address": "LoopFollow",
            "notes": "Sent via LoopFollow APNS",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": "Remote Bolus Entry: \(String(format: "%.2f", bolusAmount)) U",
        ] as [String: Any]

        if let returnInfo = createReturnNotificationInfo() {
            finalPayload["return_notification"] = returnInfo
        }

        // Log the exact bolus amount for debugging precision issues
        LogManager.shared.log(category: .apns, message: "Bolus amount - Raw: \(payload.bolusAmount ?? 0.0), Formatted: \(String(format: "%.2f", bolusAmount)), JSON: \(bolusAmount)")

        // Log the final payload for debugging
        if let payloadData = try? JSONSerialization.data(withJSONObject: finalPayload),
           let payloadString = String(data: payloadData, encoding: .utf8)
        {
            LogManager.shared.log(category: .apns, message: "Final payload being sent: \(payloadString)")
        }
        return try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: keyId,
            apnsKey: apnsKey,
            payload: finalPayload
        )
    }

    /// Sends an APNS notification
    /// - Parameters:
    ///   - deviceToken: The device token to send to
    ///   - bundleIdentifier: The bundle identifier
    ///   - keyId: The APNS key ID
    ///   - apnsKey: The APNS key
    ///   - payload: The notification payload
    /// - Returns: True if successful, false otherwise
    private func sendAPNSNotification(
        deviceToken: String,
        bundleIdentifier: String,
        keyId: String,
        apnsKey: String,
        payload: [String: Any]
    ) async throws -> Bool {
        // Create JWT token for APNS authentication
        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: keyId, teamId: Storage.shared.teamId.value ?? "", apnsKey: apnsKey) else {
            LogManager.shared.log(category: .apns, message: "Failed to create JWT using JWTManager. Check APNS credentials.")
            throw LoopAPNSError.jwtError
        }

        // Determine APNS environment
        let isProduction = storage.productionEnvironment.value
        let apnsURL = isProduction ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com"
        let requestURL = URL(string: "\(apnsURL)/3/device/\(deviceToken)")!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "apns-topic")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority") // High priority

        // Log request details for debugging
        LogManager.shared.log(category: .apns, message: "APNS Request URL: \(requestURL)")
        LogManager.shared.log(category: .apns, message: "APNS Request Headers - Authorization: Bearer \(jwt.prefix(50))..., Topic: \(bundleIdentifier)")

        // Validate bundle identifier format
        if !bundleIdentifier.contains(".") {
            LogManager.shared.log(category: .apns, message: "Warning: Bundle identifier may be in wrong format: \(bundleIdentifier)")
        }

        // Validate device token format (should be 64 hex characters)
        let deviceTokenLength = deviceToken.count
        let isHexToken = deviceToken.range(of: "^[0-9A-Fa-f]{64}$", options: .regularExpression) != nil
        LogManager.shared.log(category: .apns, message: "Device token validation - Length: \(deviceTokenLength), Is hex: \(isHexToken)")

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
            if key != "alert" && key != "content-available" && key != "interruption-level" {
                apnsPayload[key] = value
            }
        }

        // Remove nil values to clean up the payload
        let cleanPayload = apnsPayload.compactMapValues { $0 }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: cleanPayload)
            LogManager.shared.log(category: .apns, message: "APNS payload serialized successfully, size: \(jsonData.count) bytes")

            // Log the actual payload being sent
            if let payloadString = String(data: jsonData, encoding: .utf8) {
                LogManager.shared.log(category: .apns, message: "APNS payload being sent: \(payloadString)")
            }
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to serialize APNS payload: \(error.localizedDescription)")
            throw LoopAPNSError.invalidConfiguration
        }
        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    LogManager.shared.log(category: .apns, message: "APNS notification sent successfully")
                    return true
                case 400:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error 400: \(errorResponse)")
                    LogManager.shared.log(category: .apns, message: "BadDeviceToken error - this usually means:")
                    LogManager.shared.log(category: .apns, message: "1. Device token is expired or invalid")
                    LogManager.shared.log(category: .apns, message: "2. Device token is from different environment (dev vs prod)")
                    LogManager.shared.log(category: .apns, message: "3. Device token is not registered for this bundle identifier")
                    LogManager.shared.log(category: .apns, message: "Troubleshooting steps:")
                    LogManager.shared.log(category: .apns, message: "1. Refresh device token from Loop app")
                    LogManager.shared.log(category: .apns, message: "2. Check if Loop app is using same environment (dev/prod)")
                    LogManager.shared.log(category: .apns, message: "3. Verify device token is for bundle ID: \(bundleIdentifier)")
                    LogManager.shared.log(category: .apns, message: "4. Check if device token is from production environment")
                    LogManager.shared.log(category: .apns, message: "Current environment: \(storage.productionEnvironment.value ? "Production" : "Development")")
                    throw LoopAPNSError.invalidResponse
                case 403:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error 403: Forbidden - \(errorResponse)")
                    LogManager.shared.log(category: .apns, message: "This usually means the APNS key doesn't have permissions for this bundle ID")
                    LogManager.shared.log(category: .apns, message: "Troubleshooting steps:")
                    LogManager.shared.log(category: .apns, message: "1. Check that APNS key \(keyId) has 'Apple Push Notifications service (APNs)' capability enabled")
                    LogManager.shared.log(category: .apns, message: "2. Check that bundle ID \(bundleIdentifier) has 'Push Notifications' capability enabled")
                    LogManager.shared.log(category: .apns, message: "3. Verify the APNS key is associated with the bundle ID in Apple Developer account")
                    throw LoopAPNSError.unauthorized
                case 410:
                    LogManager.shared.log(category: .apns, message: "APNS error 410: Device token is invalid or expired")
                    throw LoopAPNSError.noDeviceToken
                case 429:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error 429: Too Many Requests - \(errorResponse)")
                    LogManager.shared.log(category: .apns, message: "Rate limiting error - Apple is throttling APNS requests")
                    LogManager.shared.log(category: .apns, message: "Troubleshooting steps:")
                    LogManager.shared.log(category: .apns, message: "1. Wait a few minutes before trying again")
                    LogManager.shared.log(category: .apns, message: "2. Check if you're sending too many notifications too quickly")
                    LogManager.shared.log(category: .apns, message: "3. Consider implementing exponential backoff")
                    throw LoopAPNSError.rateLimited
                default:
                    let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                    LogManager.shared.log(category: .apns, message: "APNS error \(httpResponse.statusCode): \(errorResponse)")
                    throw LoopAPNSError.networkError
                }
            } else {
                throw LoopAPNSError.networkError
            }
        } catch {
            LogManager.shared.log(category: .apns, message: "APNS request failed: \(error.localizedDescription)")
            throw LoopAPNSError.networkError
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

    func sendOverrideNotification(presetName: String, duration: TimeInterval? = nil) async throws {
        let deviceToken = Storage.shared.deviceToken.value
        guard !deviceToken.isEmpty else {
            throw LoopAPNSError.deviceTokenNotConfigured
        }

        let bundleIdentifier = Storage.shared.bundleId.value
        guard !bundleIdentifier.isEmpty else {
            throw LoopAPNSError.bundleIdentifierNotConfigured
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

        if let returnInfo = createReturnNotificationInfo() {
            payload["return_notification"] = returnInfo
        }

        // Send the notification using the existing APNS infrastructure
        try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: storage.keyId.value,
            apnsKey: storage.apnsKey.value,
            payload: payload
        )
    }

    func sendCancelOverrideNotification() async throws {
        let deviceToken = Storage.shared.deviceToken.value
        guard !deviceToken.isEmpty else {
            throw LoopAPNSError.deviceTokenNotConfigured
        }

        let bundleIdentifier = Storage.shared.bundleId.value
        guard !bundleIdentifier.isEmpty else {
            throw LoopAPNSError.bundleIdentifierNotConfigured
        }

        // Create APNS notification payload (matching Loop's expected format)
        let now = Date()
        let expiration = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes from now

        var payload: [String: Any] = [
            "cancel-temporary-override": "true",
            "remote-address": "LoopFollow",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(expiration),
            "alert": "Cancel Temporary Override",
        ]

        if let returnInfo = createReturnNotificationInfo() {
            payload["return_notification"] = returnInfo
        }

        // Send the notification using the existing APNS infrastructure
        try await sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: storage.keyId.value,
            apnsKey: storage.apnsKey.value,
            payload: payload
        )
    }
}
