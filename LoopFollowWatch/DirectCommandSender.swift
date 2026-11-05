// LoopFollow
// DirectCommandSender.swift

import Foundation

/// Sends a command from the watch straight to Loop or Trio when the phone is
/// out of reach, with the credentials and guardrails the phone last sent.
enum DirectCommandSender {
    /// At least this long between two insulin commands sent from the watch.
    static let insulinInterval: TimeInterval = 60

    private static let lastInsulinKey = "directLastInsulinAt"
    private static let lastLoopOTPKey = "directLastLoopOTP"

    static func send(_ requested: WatchCommand.Action, credentials: WatchCredentials, config: WatchRemoteConfig) async -> WatchCommandReply {
        guard let remote = credentials.remote, remote.kind == config.kind else {
            return WatchCommandReply(success: false, message: "iPhone not reachable, and commands from the watch alone are not set up. Open LoopFollow on the iPhone once.")
        }

        let action: WatchCommand.Action
        switch WatchCommandValidator.validate(requested, kind: remote.kind, limits: config.limits) {
        case let .failure(error): return WatchCommandReply(success: false, message: error.message)
        case let .success(validated): action = validated
        }

        if action.deliversInsulin, let last = UserDefaults.standard.object(forKey: lastInsulinKey) as? Date,
           Date().timeIntervalSince(last) < insulinInterval
        {
            return WatchCommandReply(success: false, message: "Insulin was sent from the watch less than a minute ago. Check Loop or Trio before sending more.")
        }

        let result: (Bool, String?)
        switch remote.kind {
        case .trio: result = await sendTrio(action, remote: remote, config: config)
        case .loop: result = await sendLoop(action, remote: remote, config: config)
        }

        LogManager.shared.log(category: .apns, message: "Direct command \(action.name) finished: success=\(result.0) \(result.1 ?? "")")
        guard result.0 else {
            return WatchCommandReply(success: false, message: result.1 ?? "Failed to send the command.")
        }
        if action.deliversInsulin {
            UserDefaults.standard.set(Date(), forKey: lastInsulinKey)
        }
        return WatchCommandReply(success: true, message: "Sent from the watch without the iPhone. Check Loop or Trio for the result.")
    }

    // MARK: - Trio

    private static func sendTrio(_ action: WatchCommand.Action, remote: WatchCredentials.Remote, config: WatchRemoteConfig) async -> (Bool, String?) {
        var payload = CommandPayload(user: remote.user, commandType: .bolus, timestamp: Date().timeIntervalSince1970, returnNotification: remote.returnNotification)
        switch action {
        case let .bolus(units):
            payload.bolusAmount = Decimal(units)
        case let .meal(carbs, fat, protein, bolus, consumedAt):
            payload.commandType = .meal
            payload.carbs = carbs > 0 ? Int(carbs) : nil
            payload.fat = fat > 0 ? Int(fat) : nil
            payload.protein = protein > 0 ? Int(protein) : nil
            payload.bolusAmount = bolus > 0 ? Decimal(bolus) : nil
            payload.scheduledTime = WatchCommand.trioScheduledTime(consumedAt)?.timeIntervalSince1970
        case let .startOverride(presetID):
            payload.commandType = .startOverride
            payload.overrideName = presetID
        case .cancelOverride:
            payload.commandType = .cancelOverride
        case let .startTempTarget(presetID):
            guard let preset = config.tempTargetPresets.first(where: { $0.id == presetID }), let target = preset.targetMgdl else {
                return (false, "The temp target preset was not found.")
            }
            payload.commandType = .tempTarget
            payload.target = Int(target)
            payload.duration = Int(preset.durationSeconds / 60)
        case .cancelTempTarget:
            payload.commandType = .cancelTempTarget
        case .snoozeAlarm, .snoozeAll:
            return (false, "Snoozing needs the iPhone.")
        }

        guard let messenger = SecureMessenger(sharedSecret: remote.sharedSecret) else {
            return (false, "Failed to initialize security module. Check shared secret.")
        }
        do {
            let message = try EncryptedPushMessage(encryptedData: messenger.encrypt(payload), commandType: payload.commandType)
            let body = try JSONEncoder().encode(message)
            return await deliver(body: body, remote: remote, expiration: "600", collapseID: payload.apnsCollapseID)
        } catch {
            return (false, "Failed to encode or encrypt push message: \(error.localizedDescription)")
        }
    }

    // MARK: - Loop

    private static func sendLoop(_ action: WatchCommand.Action, remote: WatchCredentials.Remote, config: WatchRemoteConfig) async -> (Bool, String?) {
        var payload: [String: Any]
        var usedOTP: String?

        switch action {
        case let .bolus(units):
            guard let otp = loopOTP(remote) else { return (false, otpUnavailable) }
            payload = LoopAPNSCommands.bolusCommandPayload(LoopAPNSPayload(type: .bolus, bolusAmount: units, otp: otp))
            usedOTP = otp
        case let .meal(carbs, _, _, _, consumedAt):
            guard let otp = loopOTP(remote) else { return (false, otpUnavailable) }
            payload = LoopAPNSCommands.carbsCommandPayload(LoopAPNSPayload(
                type: .carbs,
                carbsAmount: carbs,
                absorptionTime: WatchCommandValidator.loopAbsorptionHours,
                consumedDate: consumedAt.dateUsingCurrentSeconds(),
                otp: otp
            ))
            usedOTP = otp
        case let .startOverride(presetID):
            guard let preset = config.overridePresets.first(where: { $0.id == presetID }) else {
                return (false, "The override preset was not found.")
            }
            payload = LoopAPNSCommands.overridePayload(
                presetName: presetID,
                duration: preset.durationSeconds > 0 ? preset.durationSeconds : nil,
                returnInfo: remote.returnNotification
            )
        case .cancelOverride:
            payload = LoopAPNSCommands.cancelOverridePayload(returnInfo: remote.returnNotification)
        case .startTempTarget, .cancelTempTarget, .snoozeAlarm, .snoozeAll:
            return (false, "This command is not available for Loop.")
        }

        if let usedOTP, let returnInfo = remote.returnNotification,
           let messenger = OTPSecureMessenger(otpCode: usedOTP),
           let encrypted = try? messenger.encrypt(returnInfo)
        {
            payload["encrypted_return_notification"] = encrypted
        }

        do {
            let body = try LoopAPNSCommands.apnsBody(payload)
            let result = await deliver(body: body, remote: remote)
            if result.0, let usedOTP {
                UserDefaults.standard.set(usedOTP, forKey: lastLoopOTPKey)
            }
            return result
        } catch {
            return (false, "Failed to serialize APNS payload: \(error.localizedDescription)")
        }
    }

    private static let otpUnavailable = "No unused one-time code right now. Wait for the next code (up to 30 seconds) and try again."

    /// The current one-time code, unless the watch already used it: Loop rejects a code it has seen.
    private static func loopOTP(_ remote: WatchCredentials.Remote) -> String? {
        guard let otp = TOTPGenerator.extractOTPFromURL(remote.loopQRCodeURL) else { return nil }
        return otp == UserDefaults.standard.string(forKey: lastLoopOTPKey) ? nil : otp
    }

    private static func deliver(body: Data, remote: WatchCredentials.Remote, expiration: String? = nil, collapseID: String? = nil) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            APNSDelivery.send(
                body: body,
                deviceToken: remote.deviceToken,
                topic: remote.bundleID,
                production: remote.production,
                keyId: remote.keyID,
                teamId: remote.teamID,
                apnsKey: remote.apnsKey,
                expiration: expiration,
                collapseID: collapseID
            ) { success, error in
                continuation.resume(returning: (success, error))
            }
        }
    }
}
