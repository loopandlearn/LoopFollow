// LoopFollow
// LoopAPNSCommands.swift

import Foundation

/// Loop remote command payloads, matching Nightscout's loop.js format.
enum LoopAPNSCommands {
    /// Fields every Loop remote command carries.
    static func commandHeader(otp: String, alert: String, now: Date) -> [String: Any] {
        [
            "otp": otp,
            "remote-address": "LoopFollow",
            "notes": "Sent via LoopFollow APNS",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(now.addingTimeInterval(5 * 60)),
            "alert": alert,
        ]
    }

    static func carbsCommandPayload(_ payload: LoopAPNSPayload, now: Date = Date()) -> [String: Any] {
        let carbsAmount = payload.carbsAmount ?? 0.0
        let absorptionTime = payload.absorptionTime ?? 3.0
        var fields = commandHeader(
            otp: payload.otp,
            alert: "Remote Carbs Entry: \(String(format: "%.1f", carbsAmount)) grams\nAbsorption Time: \(String(format: "%.1f", absorptionTime)) hours",
            now: now
        )
        fields["carbs-entry"] = carbsAmount
        fields["absorption-time"] = absorptionTime
        fields["start-time"] = formatDateForAPNS(payload.consumedDate ?? now)
        return fields
    }

    static func bolusCommandPayload(_ payload: LoopAPNSPayload, now: Date = Date()) -> [String: Any] {
        let bolusAmount = payload.bolusAmount ?? 0.0
        var fields = commandHeader(otp: payload.otp, alert: "Remote Bolus Entry: \(String(format: "%.2f", bolusAmount)) U", now: now)
        fields["bolus-entry"] = bolusAmount
        return fields
    }

    static func carbsDeleteCommandPayload(syncIdentifier: String, otp: String, now: Date = Date()) -> [String: Any] {
        var fields = commandHeader(otp: otp, alert: "Remote Carbs Delete", now: now)
        fields["carbs-delete"] = syncIdentifier
        return fields
    }

    /// Keys are prefixed so an unpatched Loop rejects the command. Amount, absorption time and start time are always sent; food type only when set.
    static func carbsEditCommandPayload(
        syncIdentifier: String,
        carbsAmount: Double,
        absorptionTimeHours: Double,
        foodType: String?,
        consumedDate: Date,
        otp: String,
        now: Date = Date()
    ) -> [String: Any] {
        var fields = commandHeader(
            otp: otp,
            alert: "Remote Carbs Edit: \(String(format: "%.1f", carbsAmount)) grams\nAbsorption Time: \(String(format: "%.1f", absorptionTimeHours)) hours",
            now: now
        )
        fields["carbs-edit"] = syncIdentifier
        fields["carbs-edit-entry"] = carbsAmount
        fields["carbs-edit-absorption-time"] = absorptionTimeHours
        fields["carbs-edit-start-time"] = formatDateForAPNS(consumedDate)
        if let foodType, !foodType.isEmpty {
            fields["carbs-edit-food-type"] = foodType
        }
        return fields
    }

    /// Keys are prefixed so an unpatched Loop rejects the command. The fingerprint identifies the previewed profile values.
    static func profileSwitchCommandPayload(name: String, fingerprint: String, otp: String, now: Date = Date()) -> [String: Any] {
        var fields = commandHeader(otp: otp, alert: "Remote Profile Switch: \(name)", now: now)
        fields["profile-switch"] = name
        fields["profile-switch-fingerprint"] = fingerprint
        return fields
    }

    /// Creates a properly formatted ISO8601 date string with milliseconds (matching Nightscout's format)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string like "2022-12-24T21:34:02.090Z"
    /// Override commands need no one-time code, so the return block travels unencrypted.
    static func overridePayload(presetName: String, duration: TimeInterval?, returnInfo: ReturnNotificationInfo?, now: Date = Date()) -> [String: Any] {
        // Alert text matches Nightscout's format.
        var alertText = "\(presetName) Temporary Override"
        if let duration, duration > 0 {
            let hours = Int(duration / 3600)
            let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
            alertText += hours > 0 ? " (\(hours)h \(minutes)m)" : " (\(minutes)m)"
        }
        var payload = overrideHeader(alert: alertText, now: now, returnInfo: returnInfo)
        payload["override-name"] = presetName
        if let duration {
            payload["override-duration-minutes"] = Int(duration / 60)
        }
        return payload
    }

    static func cancelOverridePayload(returnInfo: ReturnNotificationInfo?, now: Date = Date()) -> [String: Any] {
        var payload = overrideHeader(alert: "Cancel Temporary Override", now: now, returnInfo: returnInfo)
        payload["cancel-temporary-override"] = "true"
        return payload
    }

    private static func overrideHeader(alert: String, now: Date, returnInfo: ReturnNotificationInfo?) -> [String: Any] {
        var payload: [String: Any] = [
            "remote-address": "LoopFollow",
            "entered-by": "LoopFollow",
            "sent-at": formatDateForAPNS(now),
            "expiration": formatDateForAPNS(now.addingTimeInterval(5 * 60)),
            "alert": alert,
        ]
        if let returnInfo {
            payload["return_notification"] = [
                "production_environment": returnInfo.productionEnvironment,
                "device_token": returnInfo.deviceToken,
                "bundle_id": returnInfo.bundleId,
                "team_id": returnInfo.teamId,
                "key_id": returnInfo.keyId,
                "apns_key": returnInfo.apnsKey,
            ]
        }
        return payload
    }

    /// Wraps command fields in the push payload Loop expects (matching @parse/node-apn).
    static func apnsBody(_ payload: [String: Any]) throws -> Data {
        var body: [String: Any] = [
            "aps": [
                "alert": payload["alert"] as? String ?? "",
                "content-available": 1,
                "interruption-level": "time-sensitive",
            ],
        ]
        for (key, value) in payload where key != "alert" && key != "content-available" && key != "interruption-level" {
            body[key] = value
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    static func formatDateForAPNS(_ date: Date) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.string(from: date)
    }
}

struct LoopAPNSPayload {
    enum PayloadType {
        case carbs
        case bolus
    }

    let type: PayloadType
    let carbsAmount: Double?
    let absorptionTime: Double?
    let foodType: String?
    let bolusAmount: Double?
    let consumedDate: Date?
    let otp: String

    init(type: PayloadType, carbsAmount: Double? = nil, absorptionTime: Double? = nil, foodType: String? = nil, bolusAmount: Double? = nil, consumedDate: Date? = nil, otp: String) {
        self.type = type
        self.carbsAmount = carbsAmount
        self.absorptionTime = absorptionTime
        self.foodType = foodType
        self.bolusAmount = bolusAmount
        self.consumedDate = consumedDate
        self.otp = otp
    }
}
