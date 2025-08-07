// LoopFollow
// TOTPGenerator.swift
// Created by codebymini.

import CommonCrypto
import Foundation

enum TOTPGenerator {
    /// Generates a TOTP code from a base32 secret
    /// - Parameter secret: The base32 encoded secret
    /// - Returns: A 6-digit TOTP code as a string
    static func generateTOTP(secret: String) -> String {
        // Decode base32 secret
        let decodedSecret = base32Decode(secret)

        // Get current time in 30-second intervals
        let timeInterval = Int(Date().timeIntervalSince1970)
        let timeStep = 30
        let counter = timeInterval / timeStep

        // Convert counter to 8-byte big-endian data
        var counterData = Data()
        for i in 0 ..< 8 {
            counterData.append(UInt8((counter >> (56 - i * 8)) & 0xFF))
        }

        // Generate HMAC-SHA1
        let key = Data(decodedSecret)
        let hmac = generateHMACSHA1(key: key, data: counterData)

        // Get the last 4 bits of the HMAC
        let offset = Int(hmac.withUnsafeBytes { $0.last! } & 0x0F)

        // Extract 4 bytes starting at the offset
        let hmacData = Data(hmac)
        let codeBytes = hmacData.subdata(in: offset ..< (offset + 4))

        // Convert to integer and get last 6 digits
        let code = codeBytes.withUnsafeBytes { bytes in
            let value = bytes.load(as: UInt32.self).bigEndian
            return Int(value & 0x7FFF_FFFF) % 1_000_000
        }

        return String(format: "%06d", code)
    }

    /// Extracts OTP from various URL formats
    /// - Parameter urlString: The URL string to parse
    /// - Returns: The OTP code as a string, or nil if not found
    static func extractOTPFromURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        // Check for TOTP format (otpauth://)
        if url.scheme == "otpauth" {
            if let secretItem = components.queryItems?.first(where: { $0.name == "secret" }),
               let secret = secretItem.value
            {
                return generateTOTP(secret: secret)
            }
        }

        // Check for regular OTP format
        if let otpItem = components.queryItems?.first(where: { $0.name == "otp" }) {
            return otpItem.value
        }

        return nil
    }

    /// Decodes a base32 string to bytes
    /// - Parameter string: The base32 encoded string
    /// - Returns: Array of decoded bytes
    private static func base32Decode(_ string: String) -> [UInt8] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var result: [UInt8] = []
        var buffer = 0
        var bitsLeft = 0

        for char in string.uppercased() {
            guard let index = alphabet.firstIndex(of: char) else { continue }
            let value = alphabet.distance(from: alphabet.startIndex, to: index)

            buffer = (buffer << 5) | value
            bitsLeft += 5

            while bitsLeft >= 8 {
                bitsLeft -= 8
                result.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }

        return result
    }

    /// Generates HMAC-SHA1 for the given key and data
    /// - Parameters:
    ///   - key: The key to use for HMAC
    ///   - data: The data to hash
    /// - Returns: The HMAC-SHA1 result as Data
    private static func generateHMACSHA1(key: Data, data: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBytes in
            data.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyBytes.baseAddress, key.count, dataBytes.baseAddress, data.count, &hmac)
            }
        }
        return Data(hmac)
    }
}
