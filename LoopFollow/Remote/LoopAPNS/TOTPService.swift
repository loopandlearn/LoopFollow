// LoopFollow
// TOTPService.swift
// Created by codebymini.

import Foundation

/// Service class for managing TOTP code usage and blocking logic
class TOTPService {
    static let shared = TOTPService()

    private init() {}

    /// Checks if the current TOTP code is blocked (already used)
    /// - Parameter qrCodeURL: The QR code URL to extract the current TOTP from
    /// - Returns: True if the TOTP is blocked, false otherwise
    func isTOTPBlocked(qrCodeURL: String) -> Bool {
        guard let currentTOTP = TOTPGenerator.extractOTPFromURL(qrCodeURL) else {
            return false
        }

        // Check if the current TOTP code equals the last sent TOTP code
        return currentTOTP == Observable.shared.lastSentTOTP.value
    }

    /// Marks the current TOTP code as used
    /// - Parameter qrCodeURL: The QR code URL to extract the current TOTP from
    func markTOTPAsUsed(qrCodeURL: String) {
        if let currentTOTP = TOTPGenerator.extractOTPFromURL(qrCodeURL) {
            Observable.shared.lastSentTOTP.set(currentTOTP)
        }
    }

    /// Resets the TOTP usage tracking (called when a new TOTP period starts)
    func resetTOTPUsage() {
        Observable.shared.lastSentTOTP.set(nil)
    }
}
