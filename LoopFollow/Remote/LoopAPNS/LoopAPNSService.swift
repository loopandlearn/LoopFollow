// LoopFollow
// LoopAPNSService.swift

import Foundation
import HealthKit

class LoopAPNSService {
    private let storage = Storage.shared

    /// Returns the effective APNs credentials for sending commands to the remote app.
    /// Same team → use LoopFollow's own key. Different team → use remote-specific key.
    private func effectiveCredentials() -> (apnsKey: String, keyId: String, teamId: String) {
        let resolved = RemoteSigningKey.resolve(
            lfTeamID: BuildDetails.default.teamID ?? "",
            remoteTeamID: storage.teamId.value ?? "",
            lfKey: (storage.lfApnsKey.value, storage.lfKeyId.value),
            remoteKey: (storage.remoteApnsKey.value, storage.remoteKeyId.value)
        )
        return (resolved.key, resolved.keyID, resolved.teamID)
    }

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

    /// Encrypts return notification info using OTP code
    private func encryptReturnNotificationInfo(returnInfo: ReturnNotificationInfo, otpCode: String) -> String? {
        guard let messenger = OTPSecureMessenger(otpCode: otpCode) else {
            LogManager.shared.log(category: .apns, message: "Failed to create OTP secure messenger")
            return nil
        }

        do {
            return try messenger.encrypt(returnInfo)
        } catch {
            LogManager.shared.log(category: .apns, message: "Failed to encrypt return notification info: \(error.localizedDescription)")
            return nil
        }
    }

    /// Validates the Loop APNS setup by checking all required fields
    /// - Returns: True if setup is valid, false otherwise
    func validateSetup() -> Bool {
        let creds = effectiveCredentials()
        let hasKeyId = !creds.keyId.isEmpty
        let hasAPNSKey = !creds.apnsKey.isEmpty
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

    private static let returnNotificationRequiredMessage = "Editing or deleting a carb entry needs LoopFollow's own APNS credentials so Loop can confirm the result. Configure them in App Settings → APN."

    /// The return-notification block encrypted with the OTP, when LoopFollow's own credentials are configured.
    private func encryptedReturnNotification(otp: String) -> String? {
        guard let returnInfo = ReturnNotificationInfo.loopFollow() else {
            LogManager.shared.log(category: .apns, message: "Return notification info unavailable; Loop cannot confirm this command")
            return nil
        }
        return encryptReturnNotificationInfo(returnInfo: returnInfo, otpCode: otp)
    }

    private func sendRemoteCommand(_ payload: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        guard validateSetup() else {
            let errorMessage = "Loop APNS Configuration not valid"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }
        let creds = effectiveCredentials()
        sendAPNSNotification(
            deviceToken: Storage.shared.deviceToken.value,
            bundleIdentifier: Storage.shared.bundleId.value,
            keyId: creds.keyId,
            apnsKey: creds.apnsKey,
            teamId: creds.teamId,
            payload: payload,
            completion: completion
        )
    }

    /// Sends a command whose only confirmation is Loop's return push, so the encrypted return block is mandatory.
    private func sendConfirmedCommand(_ payload: [String: Any], otp: String, completion: @escaping (Bool, String?) -> Void) {
        guard let encryptedReturnInfo = encryptedReturnNotification(otp: otp) else {
            completion(false, Self.returnNotificationRequiredMessage)
            return
        }
        var payload = payload
        payload["encrypted_return_notification"] = encryptedReturnInfo
        sendRemoteCommand(payload, completion: completion)
    }

    /// Deletes the Loop carb entry with this `syncIdentifier`. Requires the Loop remote carb edit patch.
    func sendCarbsDelete(syncIdentifier: String, otp: String, completion: @escaping (Bool, String?) -> Void) {
        LogManager.shared.log(category: .apns, message: "Sending carbs delete for syncIdentifier=\(LogRedactor.tail(syncIdentifier))")
        sendConfirmedCommand(LoopAPNSCommands.carbsDeleteCommandPayload(syncIdentifier: syncIdentifier, otp: otp), otp: otp, completion: completion)
    }

    /// Replaces the Loop carb entry with this `syncIdentifier`. Requires the Loop remote carb edit patch.
    func sendCarbsEdit(
        syncIdentifier: String,
        carbsAmount: Double,
        absorptionTimeHours: Double,
        foodType: String?,
        consumedDate: Date,
        otp: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        LogManager.shared.log(category: .apns, message: "Sending carbs edit for syncIdentifier=\(LogRedactor.tail(syncIdentifier)): \(String(format: "%.1f", carbsAmount))g, absorption \(String(format: "%.1f", absorptionTimeHours))h")
        let payload = LoopAPNSCommands.carbsEditCommandPayload(
            syncIdentifier: syncIdentifier,
            carbsAmount: carbsAmount,
            absorptionTimeHours: absorptionTimeHours,
            foodType: foodType,
            consumedDate: consumedDate,
            otp: otp
        )
        sendConfirmedCommand(payload, otp: otp, completion: completion)
    }

    /// Sends carbs via APNS push notification
    /// - Parameters:
    ///   - payload: The carbs payload to send
    ///   - completion: Completion handler with success status and error message
    func sendCarbsViaAPNS(payload: LoopAPNSPayload, completion: @escaping (Bool, String?) -> Void) {
        var finalPayload = LoopAPNSCommands.carbsCommandPayload(payload)
        if let encryptedReturnInfo = encryptedReturnNotification(otp: payload.otp) {
            finalPayload["encrypted_return_notification"] = encryptedReturnInfo
        }
        LogManager.shared.log(category: .apns, message: "Sending carbs: \(String(format: "%.1f", payload.carbsAmount ?? 0.0))g, absorption: \(String(format: "%.1f", payload.absorptionTime ?? 3.0))h")
        sendRemoteCommand(finalPayload, completion: completion)
    }

    /// Sends bolus via APNS push notification
    /// - Parameters:
    ///   - payload: The bolus payload to send
    ///   - completion: Completion handler with success status and error message
    func sendBolusViaAPNS(payload: LoopAPNSPayload, completion: @escaping (Bool, String?) -> Void) {
        var finalPayload = LoopAPNSCommands.bolusCommandPayload(payload)
        if let encryptedReturnInfo = encryptedReturnNotification(otp: payload.otp) {
            finalPayload["encrypted_return_notification"] = encryptedReturnInfo
        }
        LogManager.shared.log(category: .apns, message: "Sending bolus: \(String(format: "%.2f", payload.bolusAmount ?? 0.0))U")
        sendRemoteCommand(finalPayload, completion: completion)
    }

    /// Validates APNS credentials similar to PushNotificationManager
    /// - Returns: Array of validation error messages, or nil if valid
    private func validateCredentials() -> [String]? {
        var errors = [String]()

        let creds = effectiveCredentials()
        let keyId = creds.keyId
        let teamId = creds.teamId
        let apnsKey = creds.apnsKey

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
        teamId: String,
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

        // Validate bundle identifier format
        if !bundleIdentifier.contains(".") {
            LogManager.shared.log(category: .apns, message: "Warning: Bundle identifier may be in wrong format: \(bundleIdentifier)")
        }

        if payload["encrypted_return_notification"] != nil {
            LogManager.shared.log(category: .apns, message: "encrypted_return_notification is present in final APNS payload")
        } else {
            LogManager.shared.log(category: .apns, message: "WARNING: encrypted_return_notification is NOT in final APNS payload. Available keys: \(Array(payload.keys).joined(separator: ", "))")
        }

        let body: Data
        do {
            body = try LoopAPNSCommands.apnsBody(payload)
        } catch {
            let errorMessage = "Failed to serialize APNS payload: \(error.localizedDescription)"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        APNSDelivery.send(
            body: body,
            deviceToken: deviceToken,
            topic: bundleIdentifier,
            production: storage.productionEnvironment.value,
            keyId: keyId,
            teamId: teamId,
            apnsKey: apnsKey,
            completion: completion
        )
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

        let payload = LoopAPNSCommands.overridePayload(presetName: presetName, duration: duration, returnInfo: ReturnNotificationInfo.loopFollow())

        // Send the notification using the existing APNS infrastructure
        let creds = effectiveCredentials()
        sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: creds.keyId,
            apnsKey: creds.apnsKey,
            teamId: creds.teamId,
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

        let payload = LoopAPNSCommands.cancelOverridePayload(returnInfo: ReturnNotificationInfo.loopFollow())

        // Send the notification using the existing APNS infrastructure
        let creds = effectiveCredentials()
        sendAPNSNotification(
            deviceToken: deviceToken,
            bundleIdentifier: bundleIdentifier,
            keyId: creds.keyId,
            apnsKey: creds.apnsKey,
            teamId: creds.teamId,
            payload: payload,
            completion: completion
        )
    }
}
