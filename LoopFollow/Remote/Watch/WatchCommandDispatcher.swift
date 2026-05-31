// LoopFollow
// WatchCommandDispatcher.swift

import Foundation
import HealthKit

final class WatchCommandDispatcher {
    static let shared = WatchCommandDispatcher()

    private let apnsService = LoopAPNSService()

    private init() {}

    func handle(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let cmd = message["watchCmd"] as? String else {
            replyHandler(["success": false, "error": "Unknown command"])
            return
        }
        LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: handling command '\(cmd)'")
        switch cmd {
        case "carbs":
            handleCarbs(message: message, replyHandler: replyHandler)
        case "bolus":
            handleBolus(message: message, replyHandler: replyHandler)
        case "override", "preMealOverride":
            handleOverride(message: message, replyHandler: replyHandler)
        default:
            replyHandler(["success": false, "error": "Unrecognised command: \(cmd)"])
        }
    }

    // MARK: - Carbs

    private func handleCarbs(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard apnsService.validateSetup() else {
            replyHandler(["success": false, "error": "LoopAPNS not configured"])
            return
        }
        guard let otp = currentOTP() else {
            replyHandler(["success": false, "error": "OTP unavailable — check QR code in settings"])
            return
        }
        if isTOTPBlocked() {
            replyHandler(["success": false, "totpBlocked": true, "error": "OTP already used — wait up to 30 seconds"])
            return
        }

        let carbsAmount = message["carbsAmount"] as? Double ?? 0
        let absorptionTime = message["absorptionTime"] as? Double ?? 3.0

        guard carbsAmount > 0 else {
            replyHandler(["success": false, "error": "Carbs amount must be greater than 0"])
            return
        }

        let maxCarbs = Storage.shared.maxCarbs.value.doubleValue(for: .gram())
        guard carbsAmount <= maxCarbs else {
            replyHandler(["success": false, "error": "Carbs exceed maximum (\(Int(maxCarbs))g)"])
            return
        }

        let consumedDate = Date().dateUsingCurrentSeconds()
        let payload = LoopAPNSPayload(
            type: .carbs,
            carbsAmount: carbsAmount,
            absorptionTime: absorptionTime,
            consumedDate: consumedDate,
            otp: otp
        )

        apnsService.sendCarbsViaAPNS(payload: payload) { [weak self] ok, err in
            if ok {
                TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: carbs sent — \(carbsAmount)g")
            } else {
                LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: carbs failed — \(err ?? "unknown")")
            }
            replyHandler(["success": ok, "error": err ?? ""])
        }
    }

    // MARK: - Bolus

    private func handleBolus(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard apnsService.validateSetup() else {
            replyHandler(["success": false, "error": "LoopAPNS not configured"])
            return
        }
        guard let otp = currentOTP() else {
            replyHandler(["success": false, "error": "OTP unavailable — check QR code in settings"])
            return
        }
        if isTOTPBlocked() {
            replyHandler(["success": false, "totpBlocked": true, "error": "OTP already used — wait up to 30 seconds"])
            return
        }

        let bolusAmount = message["bolusAmount"] as? Double ?? 0
        guard bolusAmount > 0 else {
            replyHandler(["success": false, "error": "Bolus amount must be greater than 0"])
            return
        }

        let maxBolus = Storage.shared.maxBolus.value.doubleValue(for: .internationalUnit())
        guard bolusAmount <= maxBolus else {
            replyHandler(["success": false, "error": "Bolus exceeds maximum (\(String(format: "%.2f", maxBolus))U)"])
            return
        }

        let payload = LoopAPNSPayload(
            type: .bolus,
            bolusAmount: bolusAmount,
            otp: otp
        )

        apnsService.sendBolusViaAPNS(payload: payload) { [weak self] ok, err in
            if ok {
                TOTPService.shared.markTOTPAsUsed(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
                LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: bolus sent — \(bolusAmount)U")
            } else {
                LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: bolus failed — \(err ?? "unknown")")
            }
            replyHandler(["success": ok, "error": err ?? ""])
        }
    }

    // MARK: - Override

    private func handleOverride(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let name = message["overrideName"] as? String, !name.isEmpty else {
            replyHandler(["success": false, "error": "No override name specified"])
            return
        }
        let rawDuration = message["overrideDuration"] as? Double ?? 0
        let duration: TimeInterval? = rawDuration > 0 ? rawDuration : nil

        apnsService.sendOverrideNotification(presetName: name, duration: duration) { ok, err in
            if ok {
                LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: override '\(name)' sent")
            } else {
                LogManager.shared.log(category: .apns, message: "WatchCommandDispatcher: override '\(name)' failed — \(err ?? "unknown")")
            }
            replyHandler(["success": ok, "error": err ?? ""])
        }
    }

    // MARK: - TOTP Helpers

    private func currentOTP() -> String? {
        TOTPGenerator.extractOTPFromURL(Storage.shared.loopAPNSQrCodeURL.value)
    }

    private func isTOTPBlocked() -> Bool {
        TOTPService.shared.isTOTPBlocked(qrCodeURL: Storage.shared.loopAPNSQrCodeURL.value)
    }
}
