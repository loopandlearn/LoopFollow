// LoopFollow
// ProfileCommandPayloadTests.swift

import CryptoKit
import Foundation
@testable import LoopFollow
import Testing

struct ProfileCommandPayloadTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let headerKeys: Set<String> = ["otp", "remote-address", "notes", "entered-by", "sent-at", "expiration", "alert"]

    /// The contract example: basal [[0,0.85],[21600,1.0]], carbratio [[0,10]], sens [[0,50]], target [[0,100,110]].
    static let vector = TherapyProfileValues(
        units: "mg/dL",
        basal: [ProfileScheduleItem(seconds: 0, value: 0.85), ProfileScheduleItem(seconds: 21600, value: 1.0)],
        carbRatio: [ProfileScheduleItem(seconds: 0, value: 10)],
        sensitivity: [ProfileScheduleItem(seconds: 0, value: 50)],
        target: [ProfileRangeItem(seconds: 0, low: 100, high: 110)]
    )

    private static func assertCompact(_ object: Any?) {
        let compact = object as? [String: Any]
        #expect(Set(compact?.keys.map { $0 } ?? []) == ["units", "basal", "carbratio", "sens", "target"])
        #expect(compact?["units"] as? String == "mg/dL")
        let basal = compact?["basal"] as? [[Double]]
        #expect(basal == [[0, 0.85], [21600, 1.0]])
        #expect(compact?["carbratio"] as? [[Double]] == [[0, 10]])
        #expect(compact?["sens"] as? [[Double]] == [[0, 50]])
        #expect(compact?["target"] as? [[Double]] == [[0, 100, 110]])
    }

    @Test("compact values encode as the contract's pairs and triples")
    func compactEncoding() throws {
        let data = try JSONEncoder().encode(Self.vector)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"basal\":[[0,0.85],[21600,1]]"))
        #expect(text.contains("\"target\":[[0,100,110]]"))
        try Self.assertCompact(JSONSerialization.jsonObject(with: data))
        let viaSerialization = try JSONSerialization.data(withJSONObject: Self.vector.jsonObject)
        try Self.assertCompact(JSONSerialization.jsonObject(with: viaSerialization))
    }

    @Test("values are sent as the decimal numbers shown, in Loop and Trio commands")
    func decimalEncoding() throws {
        let values = TherapyProfileValues(
            units: "mmol/L",
            basal: [ProfileScheduleItem(seconds: 0, value: 0.7), ProfileScheduleItem(seconds: 43200, value: 0.1 + 0.2), ProfileScheduleItem(seconds: 64800, value: 1.15)],
            carbRatio: [ProfileScheduleItem(seconds: 0, value: 12.3)],
            sensitivity: [ProfileScheduleItem(seconds: 0, value: 2.9)],
            target: [ProfileRangeItem(seconds: 0, low: 5.6, high: 6.1)]
        )
        let expected = [
            "\"basal\":[[0,0.7],[43200,0.3],[64800,1.15]]",
            "\"carbratio\":[[0,12.3]]",
            "\"sens\":[[0,2.9]]",
            "\"target\":[[0,5.6,6.1]]",
        ]

        let trio = try JSONEncoder().encode(CommandPayload(user: "u", commandType: .saveProfile, timestamp: 0, commandID: "C", profileName: "P", profile: values))
        let trioText = String(decoding: trio, as: UTF8.self)
        for fragment in expected {
            #expect(trioText.contains(fragment), "Trio: \(fragment) in \(trioText)")
        }

        let loop = LoopAPNSCommands.profileSaveCommandPayload(name: "P", originalName: nil, baseFingerprint: nil, values: values, otp: "123456", now: now)
        let loopText = try String(decoding: LoopAPNSCommands.apnsBody(loop), as: UTF8.self).replacingOccurrences(of: " ", with: "")
        for fragment in expected {
            #expect(loopText.contains(fragment), "Loop: \(fragment) in \(loopText)")
        }
        #expect(!trioText.contains("0000000") && !loopText.contains("0000000"))

        // What the phone decodes has the fingerprint LoopFollow shows for the values.
        let decoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as? [String: Any])
        let basal = try #require(decoded["basal"] as? [[Double]]).map { ProfileScheduleItem(seconds: Int($0[0]), value: $0[1]) }
        #expect(basal.map(\.value) == [0.7, 0.3, 1.15])
        let roundTrip = TherapyProfileValues(units: values.units, basal: basal, carbRatio: values.carbRatio, sensitivity: values.sensitivity, target: values.target)
        #expect(roundTrip.fingerprint == values.fingerprint)
    }

    @Test("Loop profile save creates with name and values only")
    func loopSaveCreate() throws {
        let json = LoopAPNSCommands.profileSaveCommandPayload(name: "Weekend", originalName: nil, baseFingerprint: nil, values: Self.vector, otp: "123456", now: now)
        #expect(Set(json.keys) == headerKeys.union(["profile-save", "profile-save-values"]))
        #expect(json["profile-save"] as? String == "Weekend")
        #expect(json["alert"] as? String == "Remote Profile Save: Weekend")
        #expect(json["expiration"] as? String == "2023-11-14T22:18:20.000Z")
        let values = try JSONSerialization.data(withJSONObject: #require(json["profile-save-values"]))
        try Self.assertCompact(JSONSerialization.jsonObject(with: values))
    }

    @Test("Loop profile save updates or renames with the original name and base fingerprint")
    func loopSaveUpdate() throws {
        let json = LoopAPNSCommands.profileSaveCommandPayload(name: "Weekend 2", originalName: "Weekend", baseFingerprint: "3e603478d512da04", values: Self.vector, otp: "123456", now: now)
        #expect(Set(json.keys) == headerKeys.union(["profile-save", "profile-save-original-name", "profile-save-base-fingerprint", "profile-save-values"]))
        #expect(json["profile-save-original-name"] as? String == "Weekend")
        #expect(json["profile-save-base-fingerprint"] as? String == "3e603478d512da04")
        let body = try JSONSerialization.jsonObject(with: LoopAPNSCommands.apnsBody(json)) as? [String: Any]
        #expect((body?["aps"] as? [String: Any])?["alert"] as? String == "Remote Profile Save: Weekend 2")
        Self.assertCompact(body?["profile-save-values"])
    }

    @Test("Loop profile delete names the profile and its fingerprint")
    func loopDelete() {
        let json = LoopAPNSCommands.profileDeleteCommandPayload(name: "Weekend", fingerprint: "abc", otp: "123456", now: now)
        #expect(Set(json.keys) == headerKeys.union(["profile-delete", "profile-delete-fingerprint"]))
        #expect(json["profile-delete"] as? String == "Weekend")
        #expect(json["profile-delete-fingerprint"] as? String == "abc")
        #expect(json["alert"] as? String == "Remote Profile Delete: Weekend")
    }

    @Test("Trio profile commands use snake_case fields and per-command collapse ids")
    func trioPayloads() throws {
        func encode(_ payload: CommandPayload) throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any] ?? [:]
        }
        let save = CommandPayload(user: "u", commandType: .saveProfile, timestamp: 1_700_000_000, commandID: "CMD",
                                  profileName: "Weekend 2", originalProfileName: "Weekend", baseFingerprint: "3e603478d512da04", profile: Self.vector)
        let saveJSON = try encode(save)
        #expect(saveJSON["command_type"] as? String == "save_profile")
        #expect(saveJSON["profile_name"] as? String == "Weekend 2")
        #expect(saveJSON["original_profile_name"] as? String == "Weekend")
        #expect(saveJSON["base_fingerprint"] as? String == "3e603478d512da04")
        #expect(saveJSON["command_id"] as? String == "CMD")
        Self.assertCompact(saveJSON["profile"])
        #expect(save.apnsCollapseID == "CMD")

        let create = try encode(CommandPayload(user: "u", commandType: .saveProfile, timestamp: 0, commandID: "C2", profileName: "New", profile: Self.vector))
        #expect(create["original_profile_name"] == nil)
        #expect(create["base_fingerprint"] == nil)

        let switchJSON = try encode(CommandPayload(user: "u", commandType: .switchProfile, timestamp: 0, commandID: "C3", profileName: "Weekend", baseFingerprint: "f1"))
        #expect(switchJSON["command_type"] as? String == "switch_profile")
        #expect(switchJSON["base_fingerprint"] as? String == "f1")
        #expect(switchJSON["profile"] == nil)

        let deleteJSON = try encode(CommandPayload(user: "u", commandType: .deleteProfile, timestamp: 0, commandID: "C4", profileName: "Weekend", baseFingerprint: "f2"))
        #expect(deleteJSON["command_type"] as? String == "delete_profile")
        #expect(deleteJSON["profile_name"] as? String == "Weekend")
        #expect(TRCCommandType.deleteProfile.displayName == "Delete Profile")
    }

    @Test("an encrypted Trio save decrypts to the same payload with the shared secret")
    func trioEncryptionRoundTrip() throws {
        let payload = CommandPayload(user: "u", commandType: .saveProfile, timestamp: 1_700_000_000, commandID: "CMD",
                                     profileName: "Weekend", profile: Self.vector)
        let messenger = try #require(SecureMessenger(sharedSecret: "test-secret"))
        let combined = try #require(Data(base64Encoded: messenger.encrypt(payload)))
        let key = SymmetricKey(data: SHA256.hash(data: Data("test-secret".utf8)))
        let box = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(box, using: key)
        let json = try JSONSerialization.jsonObject(with: plain) as? [String: Any]
        #expect(json?["command_type"] as? String == "save_profile")
        #expect(json?["profile_name"] as? String == "Weekend")
        Self.assertCompact(json?["profile"])

        let push = try JSONSerialization.jsonObject(with: JSONEncoder().encode(EncryptedPushMessage(encryptedData: "x", commandType: .saveProfile))) as? [String: Any]
        #expect((push?["aps"] as? [String: Any])?["alert"] as? String == "Remote Command: Save Profile")
    }

    @Test("pushes over the APNs limit are refused before sending")
    func sizeLimit() async {
        let result: (Bool, String?) = await withCheckedContinuation { continuation in
            APNSDelivery.send(body: Data(count: 4097), deviceToken: "t", topic: "b", production: false, keyId: "k", teamId: "t", apnsKey: "", completion: { success, message in
                continuation.resume(returning: (success, message))
            })
        }
        #expect(result.0 == false)
        #expect(result.1 == APNSDelivery.tooLargeMessage(size: 4097))
        #expect(ProfilePushSize.tooLargeMessage(5000).contains("fewer time segments"))
    }

    @Test("the size checked with a stand-in one-time code is the size of the push sent")
    func pushSizeMatchesSentBody() throws {
        let returnInfo = ReturnNotificationInfo(
            productionEnvironment: false,
            deviceToken: String(repeating: "a", count: 64),
            bundleId: "com.TEAMID1234.LoopFollow",
            teamId: "TEAMID1234",
            keyId: "KEYID12345",
            apnsKey: "-----BEGIN PRIVATE KEY-----\n" + String(repeating: "A", count: 200) + "\n-----END PRIVATE KEY-----"
        )
        func bodySize(otp: String) throws -> Int {
            var payload = LoopAPNSCommands.profileSaveCommandPayload(name: "Sport", originalName: "Sport", baseFingerprint: "3e603478d512da04", values: Self.vector, otp: otp, now: now)
            payload["encrypted_return_notification"] = try #require(OTPSecureMessenger(otpCode: otp)).encrypt(returnInfo)
            return try LoopAPNSCommands.apnsBody(payload).count
        }
        let checked = try bodySize(otp: "000000")
        for _ in 0 ..< 20 {
            #expect(try bodySize(otp: String(format: "%06d", Int.random(in: 0 ... 999_999))) == checked)
        }
    }

    @Test("a full day of half-hour segments in every schedule does not fit in one Trio push")
    func fullDayIsTooLarge() throws {
        let starts = Array(stride(from: 0, to: 86400, by: 1800))
        let values = TherapyProfileValues(
            units: "mg/dL",
            basal: starts.map { ProfileScheduleItem(seconds: $0, value: 1.15) },
            carbRatio: starts.map { ProfileScheduleItem(seconds: $0, value: 12.5) },
            sensitivity: starts.map { ProfileScheduleItem(seconds: $0, value: 55) },
            target: starts.map { ProfileRangeItem(seconds: $0, low: 100, high: 115) }
        )
        let returnInfo = ReturnNotificationInfo(
            productionEnvironment: false,
            deviceToken: String(repeating: "a", count: 64),
            bundleId: "com.TEAMID1234.LoopFollow",
            teamId: "TEAMID1234",
            keyId: "KEYID12345",
            apnsKey: "-----BEGIN PRIVATE KEY-----\n" + String(repeating: "A", count: 200) + "\n-----END PRIVATE KEY-----"
        )
        let payload = CommandPayload(user: "Caregiver", commandType: .saveProfile, timestamp: 1_700_000_000.123, commandID: UUID().uuidString,
                                     profileName: "Full", originalProfileName: "Full", baseFingerprint: "3e603478d512da04", profile: values,
                                     returnNotification: returnInfo)
        let messenger = try #require(SecureMessenger(sharedSecret: "secret"))
        let body = try JSONEncoder().encode(EncryptedPushMessage(encryptedData: messenger.encrypt(payload), commandType: .saveProfile))
        #expect(body.count > APNSDelivery.maxPayloadBytes)

        let small = LoopAPNSCommands.profileSaveCommandPayload(name: "Small", originalName: nil, baseFingerprint: nil, values: Self.vector, otp: "123456", now: now)
        #expect(try LoopAPNSCommands.apnsBody(small).count < 1000)
    }

    /// Every schedule at `count` half-hour entries, in mmol/L with three-decimal values.
    private static func mmolValues(entries count: Int) -> TherapyProfileValues {
        let starts = (0 ..< count).map { $0 * 1800 }
        return TherapyProfileValues(
            units: "mmol/L",
            basal: starts.map { ProfileScheduleItem(seconds: $0, value: 12.345) },
            carbRatio: starts.map { ProfileScheduleItem(seconds: $0, value: 12.345) },
            sensitivity: starts.map { ProfileScheduleItem(seconds: $0, value: 12.345) },
            target: starts.map { ProfileRangeItem(seconds: $0, low: 10.005, high: 10.005) }
        )
    }

    private static let realisticReturnInfo = ReturnNotificationInfo(
        productionEnvironment: true,
        deviceToken: String(repeating: "a", count: 64),
        bundleId: "com.TEAMID1234.LoopFollow",
        teamId: "TEAMID1234",
        keyId: "KEYID12345",
        apnsKey: "-----BEGIN PRIVATE KEY-----\n" + String(repeating: "A", count: 200) + "\n-----END PRIVATE KEY-----"
    )

    private static func loopSaveSize(name: String, values: TherapyProfileValues) throws -> Int {
        var payload = LoopAPNSCommands.profileSaveCommandPayload(name: name, originalName: name, baseFingerprint: "3e603478d512da04", values: values, otp: "123456")
        payload["encrypted_return_notification"] = try #require(OTPSecureMessenger(otpCode: "123456")).encrypt(realisticReturnInfo)
        return try LoopAPNSCommands.apnsBody(payload).count
    }

    private static func trioSaveSize(name: String, values: TherapyProfileValues) throws -> Int {
        let payload = CommandPayload(user: "Caregiver", commandType: .saveProfile, timestamp: Date().timeIntervalSince1970, commandID: UUID().uuidString,
                                     profileName: name, originalProfileName: name, baseFingerprint: "3e603478d512da04", profile: values,
                                     returnNotification: realisticReturnInfo)
        let messenger = try #require(SecureMessenger(sharedSecret: "secret"))
        return try JSONEncoder().encode(EncryptedPushMessage(encryptedData: messenger.encrypt(payload), commandType: .saveProfile)).count
    }

    @Test("the largest profile the phones accept, in mmol/L with a long unicode name, is over the APNs limit for Loop and Trio")
    func largestProfileIsTooLarge() throws {
        let longName = String(repeating: "👨‍👩‍👧‍👦", count: ProfileValidation.maxNameLength)
        #expect(ProfileValidation.nameProblem(longName, existingNames: []) == nil)
        let largest = Self.mmolValues(entries: 48)
        #expect(try Self.loopSaveSize(name: longName, values: largest) > APNSDelivery.maxPayloadBytes)
        #expect(try Self.trioSaveSize(name: longName, values: largest) > APNSDelivery.maxPayloadBytes)
        // 48 entries in every schedule are too large even with a short name.
        #expect(try Self.loopSaveSize(name: "Sport", values: largest) > APNSDelivery.maxPayloadBytes)
        #expect(try Self.trioSaveSize(name: "Sport", values: largest) > APNSDelivery.maxPayloadBytes)
        // A day of hourly entries in every schedule fits both.
        let hourly = Self.mmolValues(entries: 24)
        #expect(try Self.loopSaveSize(name: "Sport", values: hourly) <= APNSDelivery.maxPayloadBytes)
        #expect(try Self.trioSaveSize(name: "Sport", values: hourly) <= APNSDelivery.maxPayloadBytes)
    }
}
