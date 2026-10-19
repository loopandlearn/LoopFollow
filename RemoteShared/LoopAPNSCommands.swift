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

    /// Creates a properly formatted ISO8601 date string with milliseconds (matching Nightscout's format)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string like "2022-12-24T21:34:02.090Z"
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
