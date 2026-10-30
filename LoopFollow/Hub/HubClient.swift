// LoopFollow
// HubClient.swift

import Combine
import CryptoKit
import Foundation
import UIKit
import UserNotifications

/// Client for an LF Hub: a server that follows the patient's Nightscout and
/// does work on this device's behalf over APNs: the badge, the Live Activity
/// and the alarms. While the hub drives them, the app does not do that work itself.
final class HubClient {
    static let shared = HubClient()
    private init() {}

    /// What a device may do at the hub: an admin manages the patient's data sources,
    /// devices and invites; a member follows. A role this app does not know counts as member.
    enum Role: String, Codable {
        case admin
        case member

        init(from decoder: Decoder) throws {
            self = try Role(rawValue: decoder.singleValueContainer().decode(String.self)) ?? .member
        }
    }

    /// The answer to joining, with the setup token or with an invite.
    struct ClaimResponse: Decodable {
        let deviceId: String
        let deviceKey: String
        let patientId: String
        /// Absent on a hub without roles, where every device manages.
        let role: Role?
    }

    /// An invite to join a hub as a member, in the form its QR code carries:
    /// `<hub address>/join#<code>`.
    struct Invite: Equatable {
        let hubURL: String
        let code: String

        var link: String { hubURL + "/join#" + code }

        init?(hubURL: String, code: String) {
            guard let base = try? HubClient.hubBase(hubURL), Self.isCode(code) else { return nil }
            self.hubURL = base
            self.code = code
        }

        /// Reads an invite link as scanned or pasted. Only an https hub, or a local test
        /// hub over http, with no user name or password in the address.
        init?(link: String) {
            guard var components = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
                  ["https", "http"].contains(components.scheme?.lowercased()),
                  !(components.host ?? "").isEmpty,
                  components.user == nil, components.password == nil,
                  let code = components.fragment
            else { return nil }
            var path = components.path
            if path.hasSuffix("/") { path.removeLast() }
            guard path.hasSuffix("/join") else { return nil }
            components.path = String(path.dropLast("/join".count))
            components.query = nil
            components.fragment = nil
            guard let base = components.string else { return nil }
            self.init(hubURL: base, code: code)
        }

        /// The invite a paste put in the field: the text grew by more than one character at
        /// once into an invite link. Typed text is read only on Continue.
        static func pasted(from old: String, to new: String) -> Invite? {
            guard new.count - old.count > 1 else { return nil }
            return Invite(link: new)
        }

        /// The hub's codes are random bytes in base64url.
        private static func isCode(_ code: String) -> Bool {
            (16 ... 128).contains(code.count)
                && code.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
        }
    }

    struct InviteResponse: Decodable {
        let code: String
        let expiresAt: Date
    }

    /// A device of the hub's patient. The list offered when joining leaves out the
    /// push fields and `current`.
    struct Device: Decodable, Identifiable, Equatable {
        let id: UUID
        let name: String
        /// Absent on a hub without roles.
        let role: Role?
        let createdAt: Date
        let lastSeenAt: Date?
        let appVersion: String?
        let lastPushOkAt: Date?
        let pushFailingSince: Date?
        let current: Bool?
    }

    struct DeviceList: Decodable {
        let devices: [Device]
        /// The patient's name, in the lists offered when joining; absent on an older hub.
        var patientName: String?
    }

    /// Replacing a device used this recently asks first: it may still be in use.
    static let recentUse: TimeInterval = 15 * 60

    /// The question to ask before replacing a device used within `recentUse`, if it was.
    static func recentUseWarning(_ device: Device, now: Date) -> String? {
        guard let seen = device.lastSeenAt else { return nil }
        let ago = max(0, now.timeIntervalSince(seen))
        guard ago < recentUse else { return nil }
        let minutes = Int(ago / 60)
        let when = minutes < 1 ? "just now" : minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        return "\(device.name) was used \(when). Replace it anyway?"
    }

    /// How this phone joins a hub that already has devices.
    enum Join: Hashable {
        /// A new device with no alarms or settings at the hub.
        case new
        /// This phone takes over the device: its alarms and settings, under a new key.
        case replace(UUID)
        /// A new device starting with a copy of that device's alarms and settings.
        case copy(UUID)
    }

    /// The patient's data sources at the hub, as an app sent them.
    struct Sources: Decodable, Equatable {
        struct Dexcom: Decodable, Equatable {
            let username: String
            let password: String
            let server: String?
        }

        let nightscoutUrl: String?
        let token: String?
        let dexcom: Dexcom?

        var isEmpty: Bool { (nightscoutUrl ?? "").isEmpty && dexcom == nil }
    }

    struct Status: Decodable {
        struct Device: Decodable {
            let name: String
            /// Absent on a hub without roles, where every device manages.
            let role: Role?
            let apnsConfigured: Bool
            /// The hub pushes to this device with an admin device's APN key.
            let apnsKeyShared: Bool?
            let apnsEnvironment: String?
            let lastPushAt: Date?
            let lastPushStatus: String?
            let lastPushOkAt: Date?
            let pushFailingSince: Date?
            let alarmsReceived: Bool?
            let alarmCount: Int?
            let lastAlarmPushOk: Bool?
            let disabledAlarmIds: [String]?
            let activeAlarm: ActiveAlarm?
            let liveActivity: LiveActivity
            let settings: Settings?
        }

        /// What the hub drives for the device.
        struct Settings: Decodable {
            let alarms: Bool?
        }

        struct ActiveAlarm: Decodable {
            let alarmId: String?
            let title: String
            let firedAt: Date
            let lastPushAt: Date
            let lastPushStatus: String?
        }

        struct LiveActivity: Decodable {
            let registered: Bool
            let pushToStartRegistered: Bool
            let renewBy: Date?
            let renewalFailed: Bool
            let lastPushAt: Date?
            let lastPushStatus: String?
        }

        struct Patient: Decodable {
            let name: String
            let nightscoutHost: String?
            let dexcom: Bool?
            let followed: Bool?
            let hasData: Bool?
            /// Counts the changes of the patient's data sources.
            let sourceRevision: Int?
        }

        struct Live: Decodable {
            let connected: Bool
            let lastReadingAt: Date?
            let staleAfterSeconds: Int
        }

        /// What the hub reports about itself; absent on a hub older than the version exchange.
        struct Hub: Codable, Equatable {
            let version: String
            let api: Int
            let features: [String]
        }

        let hub: Hub?
        let device: Device
        let patient: Patient
        let live: Live
    }

    /// The API version this app speaks.
    static let api = 1
    /// What this app supports, reported to the hub: delivery receipts for alarm pushes, and
    /// speaking the hub's Speak BG pushes.
    static let features = ["receipts", "speak"]
    /// What the hub must provide before this app lets it deliver the alarms.
    static let requiredHubFeatures = ["receipts"]

    enum HubError: LocalizedError {
        case notConnected
        case invalidURL
        case keyNotSaved
        case inviteNotValid
        case tooManyTries
        case invitedPhone
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConnected: return "Not connected to a hub."
            case .invalidURL: return "The hub URL is not valid."
            case .keyNotSaved: return "The hub's key for this phone could not be saved."
            case .inviteNotValid: return "This invite has expired or was already used. Ask for a new one."
            case .tooManyTries: return "Too many tries. Wait a minute and try again."
            case .invitedPhone: return "A phone that joined with an invite does not send its own data sources to the hub."
            case let .http(code, message): return "Hub responded \(code): \(message)"
            }
        }
    }

    /// An error in plain words for the user. The hub's own detail stays in the log.
    static func userMessage(for error: Error) -> String {
        switch error {
        case let HubError.http(code, detail):
            let lower = detail.lowercased()
            switch code {
            case 401: return "This phone is no longer part of LF Hub."
            case 403 where lower.contains("take over"): return "A phone that joins with an invite cannot replace an admin's phone."
            case 403 where lower.contains("admin"): return "Only an admin can do this."
            case 403 where lower.contains("invite"): return HubError.inviteNotValid.errorDescription ?? ""
            case 403 where lower.contains("setup token"): return "The setup token is not right."
            case 403: return "LF Hub did not allow this."
            case 404: return "LF Hub does not know this phone or device. It may have been removed."
            case 409 where lower.contains("admin"):
                return "LF Hub needs at least one admin. Make another phone an admin first."
            case 409 where lower.contains("apns"):
                return "LF Hub cannot notify this phone yet. Add the APN key under Settings → APN."
            case 409: return "LF Hub cannot do this yet. Check the Ready list."
            case 429: return HubError.tooManyTries.errorDescription ?? ""
            case 502 where lower.hasPrefix("apns:"):
                let status = detail.dropFirst("apns:".count).trimmingCharacters(in: .whitespaces)
                return "Apple rejected the push: \(pushFailureReason(status))"
            case 500...: return "LF Hub had a problem. Try again in a moment."
            default: return "LF Hub did not accept this: \(detail)"
            }
        case HubError.notConnected: return HubError.notConnected.errorDescription ?? ""
        case let error as HubError: return error.errorDescription ?? ""
        case let error as URLError:
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost: return "This phone is offline. Try again when it is online."
            case .timedOut: return "LF Hub did not answer in time. Try again in a moment."
            default: return "LF Hub could not be reached. Check the address, or try again in a moment."
            }
        default: return error.localizedDescription
        }
    }

    /// The key this device authenticates to the hub with.
    let deviceKey = HubDeviceKey()

    var isConnected: Bool {
        !Storage.shared.hubURL.value.isEmpty && !deviceKey.value.isEmpty
    }

    /// This device's role: admin after joining with the setup token, member after joining
    /// with an invite, and then as the hub last said. A hub without roles lets every device
    /// it did not invite manage.
    let role = StorageValue<Role>(key: "hubRole", defaultValue: .admin)
    /// This phone joined with an invite. It never sends the hub its own data sources or
    /// APN key, whatever role the hub gives it.
    let joinedWithInvite = StorageValue<Bool>(key: "hubJoinedWithInvite", defaultValue: false)
    /// A device this phone left whose removal the hub has not confirmed yet.
    let pendingUnregistration = HubPendingUnregistration()
    /// The hub pushes to this device with an admin device's APN key, as it last said.
    let apnsKeyShared = StorageValue<Bool>(key: "hubApnsKeyShared", defaultValue: false)
    /// The patient's name at the hub, for messages about changes that reach every phone.
    let patientName = StorageValue<String>(key: "hubPatientName", defaultValue: "")
    /// The hub stopped knowing this phone's key (the phone was replaced or removed), until
    /// the phone joins again or the user dismisses the message.
    let removedFromHub = StorageValue<Bool>(key: "hubRemovedFromHub", defaultValue: false)

    /// Connected, and allowed to manage the patient's data sources, devices and invites.
    var isAdmin: Bool { isConnected && role.value == .admin }

    /// Connected as a member: the data sources and the devices are the admins' to manage.
    var isMember: Bool { isConnected && role.value == .member }

    /// Connected as an admin that did not join with an invite: this app's data sources go
    /// to the hub. An admin that joined with an invite sends them only on a change the
    /// user confirms.
    var sendsOwnSources: Bool { isAdmin && !joinedWithInvite.value }

    /// The role after joining: an invite makes a member, the setup token an admin.
    static func joinRole(withInvite: Bool) -> Role {
        withInvite ? .member : .admin
    }

    /// The role the hub reports, or without one the role joining gave.
    static func role(reported: Role?, joinedWithInvite: Bool) -> Role {
        reported ?? joinRole(withInvite: joinedWithInvite)
    }

    /// The connected hub reported the feature in its last status.
    func offers(_ feature: String) -> Bool {
        isConnected && hubInfo.value?.features.contains(feature) == true
    }

    /// This app holds an APN key of its own under Settings → APN.
    static var hasOwnApnKey: Bool {
        !Storage.shared.lfKeyId.value.isEmpty && !Storage.shared.lfApnsKey.value.isEmpty
    }

    /// The hub can push to this phone with a key: this app's own or one an admin shares.
    var hasApnKey: Bool { Self.hasOwnApnKey || (isConnected && apnsKeyShared.value) }

    /// LF Hub needs iOS 26: its alarms ring through silent mode as AlarmKit alarms.
    static var isSupported: Bool {
        #if targetEnvironment(macCatalyst)
            return false
        #else
            if #available(iOS 26, *) { return true }
            return false
        #endif
    }

    /// The LoopFollow Hub background mode is selected and the app is connected to a
    /// hub. The hub drives the features only once it confirmed it can (`drivesAlarms`).
    var isHubMode: Bool {
        Self.isSupported && isConnected && Storage.shared.backgroundRefreshType.value == .hub
    }

    /// In Hub mode the hub checks the alarms and delivers them, and the app does not
    /// keep itself running. Only once the hub has confirmed it is set up to (push
    /// registered and reaching the phone, alarms received and on, patient followed),
    /// while it looks healthy, and with AlarmKit allowed, so its alarms ring through
    /// silent mode. Until then the app alarms itself and keeps itself running as in
    /// Silent Tune.
    var drivesAlarms: Bool {
        isHubMode && hubConfirmed.value && HubWatchdog.hubLooksHealthy && Self.alarmKitAuthorized
            && notificationsAllowed.value
    }

    /// Notifications for LoopFollow are allowed and show alerts, as iOS last said. Read at
    /// launch, on each watchdog check and on each return to the foreground.
    let notificationsAllowed = StorageValue<Bool>(key: "hubNotificationsAllowed", defaultValue: false)

    /// Notifications reach the user: allowed, not provisional, with alerts on.
    static func notificationsAllow(_ status: UNAuthorizationStatus, alertSetting: UNNotificationSetting) -> Bool {
        status == .authorized && alertSetting == .enabled
    }

    /// Reads the notification permission. A change updates the hub's confirmation; losing
    /// it makes the app alarm itself again.
    func readNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let allowed = Self.notificationsAllow(settings.authorizationStatus, alertSetting: settings.alertSetting)
        let changed = await MainActor.run { () -> Bool in
            guard allowed != notificationsAllowed.value else { return false }
            let wasDriving = drivesAlarms
            notificationsAllowed.value = allowed
            LogManager.shared.log(category: .hub, message: "Notifications for LoopFollow \(allowed ? "allowed" : "not allowed")")
            if wasDriving, !drivesAlarms { MainViewController.shared?.backgroundModeChanged() }
            return true
        }
        if changed, isHubMode { await refreshStatus() }
    }

    /// The alarm types each hub API version checks, from the hub's Engine/Alarms/AlarmType.cs.
    /// A hub skips an alarm of a type it does not know; this app checks those itself.
    static let hubAlarmTypes: [Int: Set<AlarmType>] = [
        1: [.temporary, .iob, .cob, .low, .high, .fastDrop, .fastRise, .missedReading, .notLooping, .missedBolus,
            .futureCarbs, .sensorChange, .pumpChange, .pump, .pumpBattery, .battery, .batteryDrop, .recBolus,
            .overrideStart, .overrideEnd, .tempTargetStart, .tempTargetEnd, .buildExpire, .dbSize],
    ]

    /// Whether a hub speaking `api` checks alarms of this type; the newest list at or below
    /// that version counts.
    static func hubChecks(_ type: AlarmType, api: Int?) -> Bool {
        guard let api, let version = hubAlarmTypes.keys.filter({ $0 <= api }).max() else { return false }
        return hubAlarmTypes[version]?.contains(type) == true
    }

    /// The alarms the app checks itself while the hub drives the alarms: those of a type
    /// the connected hub does not check.
    func alarmsCheckedHere(_ alarms: [Alarm]) -> [Alarm] {
        Self.alarmsCheckedHere(alarms, hubAPI: hubInfo.value?.api)
    }

    static func alarmsCheckedHere(_ alarms: [Alarm], hubAPI: Int?) -> [Alarm] {
        alarms.filter { !hubChecks($0.type, api: hubAPI) }
    }

    /// How many of the alarms the hub should hold after reading this app's export: those
    /// of a type it checks.
    static func alarmCountForHub(_ alarms: [Alarm], hubAPI: Int?) -> Int {
        alarms.filter { hubChecks($0.type, api: hubAPI) }.count
    }

    /// The hub sets the app badge while it drives the alarms; the app leaves it alone.
    var drivesBadge: Bool { drivesAlarms }

    /// The hub updates and renews the Live Activity while it drives the alarms. The
    /// app still starts the activity and reports its tokens.
    var drivesLiveActivity: Bool { drivesAlarms }

    /// In Hub mode the hub speaks each reading for Speak BG, under the same
    /// conditions as it drives the alarms.
    var drivesSpeech: Bool { drivesAlarms }

    /// The hub confirmed that it can deliver this device's alarms: alarms on, push
    /// registered and reaching the phone, the latest alarm list received, the patient
    /// followed, AlarmKit allowed. Cleared when Hub mode is entered or an alarm upload
    /// fails, until the hub confirms again.
    let hubConfirmed = StorageValue<Bool>(key: "hubConfirmedAlarms", defaultValue: false)
    /// Why the hub has not confirmed, in words for the user; empty while it has, and
    /// before the first answer.
    let hubProblems = StorageValue<[String]>(key: "hubConfirmationProblems", defaultValue: [])
    /// What the hub reported about itself in its last status, while connected.
    let hubInfo = StorageValue<Status.Hub?>(key: "hubInfo", defaultValue: nil)
    private let sentKeyFingerprint = StorageValue<String>(key: "hubSentKeyFingerprint", defaultValue: "")

    /// The stored values that change what the hub builds for this device
    /// (snapshot fields, alarm input). Sent as stored, with the phone's time
    /// zone, decimal separator and time format.
    static var clientSettings: [any ClientSetting] {
        let storage = Storage.shared
        return [
            storage.units, storage.predictionToLoad, storage.downloadPrediction, storage.downloadTreatments,
            storage.downloadDays, storage.showYesterdayLine, storage.bgUpdateDelay, storage.infoDisplayItems,
            storage.persistentNotification, storage.speakBG, storage.speakBGAlways, storage.speakLowBG,
            storage.speakProactiveLowBG, storage.speakHighBG, storage.speakFastDropDelta, storage.speakLowBGLimit,
            storage.speakHighBGLimit, storage.speakLanguage,
        ]
    }

    static var clientSettingKeys: [String] { clientSettings.map(\.key) }

    private var cancellables = Set<AnyCancellable>()
    private var uploadsObserved = false

    /// An alarm or client-settings change the hub has not received yet. Kept
    /// across launches, so a change made offline reaches the hub on the next sync.
    private let alarmsPending = StorageValue<Bool>(key: "hubAlarmsUploadPending", defaultValue: false)
    private let clientSettingsPending = StorageValue<Bool>(key: "hubClientSettingsUploadPending", defaultValue: false)
    /// What the hub drives changed (Hub mode entered or left) and the hub has not
    /// taken it yet.
    let hubSettingsPending = StorageValue<Bool>(key: "hubSettingsUploadPending", defaultValue: false)

    /// What this phone takes from the hub after joining as an existing device or a copy of one.
    enum Adoption: String, Codable {
        case none
        /// The device's alarms and client settings, as they are.
        case replaced
        /// The device's alarms and client settings, without its snoozes.
        case copied
    }

    /// The hub holds alarms and client settings this phone has not taken yet; until
    /// it has, neither is uploaded.
    private let adoptionPending = StorageValue<Adoption>(key: "hubAdoptionPending", defaultValue: .none)

    /// Uploads the alarms whenever they change (a snooze edits them too), the
    /// client settings whenever one of them or the time zone or locale changes, what
    /// the hub drives whenever the badge or Live Activity setting changes, and a change
    /// of Hub mode the hub has not taken yet. The data sources follow `HubSourceSync`.
    func observeChanges() {
        guard !uploadsObserved else { return }
        uploadsObserved = true
        shareHubURL()
        Task { await readNotificationPermission() }
        Task { @MainActor in HubSourceSync.shared.observe() }

        Storage.shared.alarms.$value.map { _ in () }
            .merge(with: Storage.shared.alarmConfiguration.$value.map { _ in () })
            .dropFirst(2)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                alarmsPending.value = true
                uploadSoon { client in
                    try await client.uploadAlarms()
                    if client.isHubMode { try await client.confirm() }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange),
                   NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification))
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .map { _ in Self.currentClientSettings() as NSDictionary }
            .prepend(Self.currentClientSettings() as NSDictionary)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                clientSettingsPending.value = true
                uploadSoon { try await $0.uploadClientSettings() }
            }
            .store(in: &cancellables)

        Storage.shared.appBadge.$value.map { _ in () }
            .merge(with: Storage.shared.laEnabled.$value.map { _ in () })
            .dropFirst(2)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, isHubMode else { return }
                hubSettingsPending.value = true
                uploadSoon { try await $0.pushHubSettings() }
            }
            .store(in: &cancellables)

        if hubSettingsPending.value { uploadSoon { try await $0.pushHubSettings() } }
    }

    /// Waits between upload attempts; the last one is followed by the next sync.
    private static let uploadRetryDelays: [UInt64] = [5, 15, 30, 60, 120]

    /// Runs an upload with background time, so a snooze tapped on the lock
    /// screen reaches the hub before iOS suspends the app again, and retries it
    /// while the app runs (the hub is briefly away while it restarts).
    private func uploadSoon(_ upload: @escaping (HubClient) async throws -> Void) {
        guard isConnected else { return }
        Task { @MainActor in
            let backgroundTime = BackgroundTime(name: "LF Hub upload")
            for (attempt, delay) in ([0] + Self.uploadRetryDelays).enumerated() {
                if delay > 0 { try? await Task.sleep(nanoseconds: delay * 1_000_000_000) }
                guard isConnected else { break }
                do {
                    try await upload(self)
                    if attempt > 0 {
                        LogManager.shared.log(category: .hub, message: "Hub upload succeeded on attempt \(attempt + 1)")
                    }
                    break
                } catch {
                    LogManager.shared.log(category: .hub, message: "Hub upload attempt \(attempt + 1) failed: \(error.localizedDescription)")
                    if !Self.isRetryable(error) { break }
                }
            }
            backgroundTime.end()
        }
    }

    /// A failure that may pass on its own: no answer, the hub's own error, or its
    /// rate limit. A rejected request fails again the same way.
    static func isRetryable(_ error: Error) -> Bool {
        switch error {
        case let HubError.http(code, _): return code >= 500 || code == 429
        case HubError.notConnected, HubError.invalidURL: return false
        default: return true
        }
    }

    /// Background time for an upload. When iOS takes it back, the upload's
    /// retries go on the next time the app runs.
    @MainActor private final class BackgroundTime {
        private var id = UIBackgroundTaskIdentifier.invalid

        init(name: String) {
            id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in self?.end() }
        }

        func end() {
            guard id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(id)
            id = .invalid
        }
    }

    // MARK: - Calls

    /// The hub's address as entered, without surrounding space and slashes. Keys and
    /// credentials travel to the hub, so only a local test hub may use plain http.
    static func hubBase(_ url: String) throws -> String {
        let base = url.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let parsed = URL(string: base),
              parsed.scheme == "https" || ["localhost", "127.0.0.1"].contains(parsed.host ?? "")
        else { throw HubError.invalidURL }
        return base
    }

    /// The patient's devices at the hub, offered when joining; empty for a fresh hub.
    /// A hub without the device list answers 404 and takes new devices only.
    func joinableDevices(url: String, setupToken: String) async throws -> DeviceList {
        let base = try Self.hubBase(url)
        let (data, code) = try await request("POST", "/v1/claim/devices", body: ["setupToken": setupToken],
                                             baseURL: base, key: nil)
        switch code {
        case 200: return try Self.decoder.decode(DeviceList.self, from: data)
        case 404: return DeviceList(devices: [])
        default: throw Self.httpError(code, data)
        }
    }

    /// The patient's devices offered when joining with the invite: any to copy, a member's
    /// to take over.
    func joinableDevices(invite: Invite) async throws -> DeviceList {
        let (data, code) = try await request("POST", "/v1/join/devices", body: ["code": invite.code],
                                             baseURL: invite.hubURL, key: nil)
        guard code == 200 else { throw Self.joinError(code, data) }
        return try Self.decoder.decode(DeviceList.self, from: data)
    }

    /// Joins the hub as an admin device with the setup token, as `join` says, creating the
    /// patient on a fresh hub. The patient's data sources at the hub become this app's; a
    /// hub without sources gets this app's.
    func claim(url: String, setupToken: String, patientName: String, deviceName: String,
               join: Join = .new) async throws
    {
        let base = try Self.hubBase(url)
        var body = Self.joinBody(join, deviceName: deviceName)
        body["setupToken"] = setupToken
        body["patientName"] = patientName
        let data = try await send("POST", "/v1/claim", body: body, baseURL: base, key: nil)
        try await joined(base: base, JSONDecoder().decode(ClaimResponse.self, from: data), join: join, withInvite: false)
    }

    /// Joins the hub with an invite as a member device, as `join` says; the invite is used up.
    /// The patient's data sources at the hub become this app's.
    func join(invite: Invite, deviceName: String, join: Join = .new) async throws {
        let (data, code) = try await request("POST", "/v1/join", body: Self.joinBody(join, deviceName: deviceName)
            .merging(["code": invite.code]) { $1 }, baseURL: invite.hubURL, key: nil)
        guard (200 ..< 300).contains(code) else { throw Self.joinError(code, data) }
        try await joined(base: invite.hubURL, JSONDecoder().decode(ClaimResponse.self, from: data), join: join,
                         withInvite: true)
    }

    private static func joinBody(_ join: Join, deviceName: String) -> [String: String] {
        var body = ["deviceName": deviceName]
        switch join {
        case .new: break
        case let .replace(id): body["replace"] = id.uuidString.lowercased()
        case let .copy(id): body["copyFrom"] = id.uuidString.lowercased()
        }
        return body
    }

    /// An invite the hub does not take, and its rate limit, in words for the user.
    private static func joinError(_ code: Int, _ data: Data) -> HubError {
        switch code {
        case 403 where (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            == "unknown, used or expired invite": return .inviteNotValid
        case 429: return .tooManyTries
        default: return httpError(code, data)
        }
    }

    /// Stores the new device's key and the role joining gives. A replaced or copied
    /// device's alarms and client settings become this app's, and the hub's data sources
    /// this app's; a phone that joined with the setup token gives a hub without sources
    /// this app's. Once the key is stored the phone is connected: a step after it that
    /// fails is done by a later sync.
    private func joined(base: String, _ claim: ClaimResponse, join: Join, withInvite: Bool) async throws {
        let joinRole = Self.joinRole(withInvite: withInvite)
        try await MainActor.run {
            switch join {
            case .new: adoptionPending.value = .none
            case .replace: adoptionPending.value = .replaced
            case .copy: adoptionPending.value = .copied
            }
            try deviceKey.set(claim.deviceKey)
            uploads.forget()
            removedFromHub.value = false
            role.value = joinRole
            joinedWithInvite.value = withInvite
            // The new device has no APN key at the hub yet.
            sentKeyFingerprint.value = ""
            Storage.shared.hubURL.value = base
        }
        shareHubURL()
        LogManager.shared.log(category: .hub, message: "Joined hub as \(joinRole.rawValue)"
            + (claim.role.map { $0 == joinRole ? "" : " (hub said \($0.rawValue))" } ?? "") + ": \(join.logDescription)")

        do {
            try await adoptIfPending()
            let status = try await status()
            await record(status)
            try await HubSourceSync.shared.takeHubSources(revision: status.patient.sourceRevision,
                                                          sendOwnIfNone: !withInvite)
        } catch {
            LogManager.shared.log(category: .hub, message: "Joined, but setting up with the hub failed; a later sync finishes it: \(error.localizedDescription)")
        }
    }

    /// Makes the hub's alarms and client settings for this device this app's own, once
    /// after joining as an existing device or a copy of one. A part the hub does not
    /// hold stays as it is here.
    private func adoptIfPending() async throws {
        let adoption = adoptionPending.value
        guard adoption != .none else { return }
        let alarms = try await optionalData("/v1/device/alarms")
        let settings = try await optionalData("/v1/device/clientsettings")
        let export = try alarms.map { try JSONDecoder().decode(AlarmSettingsExport.self, from: $0) }
        let values = try settings.map { data in
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Client settings are not an object"))
            }
            return object
        }
        await MainActor.run {
            if let export { Self.apply(export, keepSnoozes: adoption == .replaced) }
            if let values { Self.applyClientSettings(values) }
            adoptionPending.value = .none
            NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
        }
        LogManager.shared.log(category: .hub, message: "Took \(export?.alarms.count ?? 0) alarms"
            + (values == nil ? "" : " and the client settings") + " from the hub")
    }

    /// Replaces this app's alarms and alarm configuration with the export's. A copy
    /// starts unsnoozed and unmuted.
    @MainActor static func apply(_ export: AlarmSettingsExport, keepSnoozes: Bool) {
        var alarms = export.alarms
        var configuration = export.alarmConfiguration
        if !keepSnoozes {
            for index in alarms.indices {
                alarms[index].snoozedUntil = nil
            }
            configuration.snoozeUntil = nil
            configuration.muteUntil = nil
        }
        Storage.shared.alarms.value = alarms
        Storage.shared.alarmConfiguration.value = configuration
    }

    /// Sets each client setting the hub holds in a form its stored value takes; the
    /// rest stay as they are.
    @MainActor static func applyClientSettings(_ values: [String: Any]) {
        for setting in clientSettings {
            guard let value = values[setting.key],
                  let json = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            else { continue }
            if !setting.assign(json: json) {
                LogManager.shared.log(category: .hub, message: "Hub client setting \(setting.key) skipped: unexpected form")
            }
        }
    }

    func status() async throws -> Status {
        let data = try await send("GET", "/v1/me")
        return try Self.decoder.decode(Status.self, from: data)
    }

    /// The patient's devices at the hub, this one marked `current`.
    func devices() async throws -> [Device] {
        try Self.decoder.decode(DeviceList.self, from: await send("GET", "/v1/devices")).devices
    }

    /// Removes another device of the patient from the hub; its key stops working. Admins only.
    func deleteDevice(_ id: UUID) async throws {
        _ = try await send("DELETE", "/v1/devices/\(id.uuidString.lowercased())")
    }

    /// Makes a device of the patient an admin or a member. Admins only; the hub keeps one admin.
    func setRole(_ role: Role, of id: UUID) async throws {
        _ = try await send("PUT", "/v1/devices/\(id.uuidString.lowercased())/role", body: ["role": role.rawValue])
    }

    /// A new invite for one phone to join as a member. Admins only.
    func createInvite() async throws -> (invite: Invite, expiresAt: Date) {
        let response = try Self.decoder.decode(InviteResponse.self, from: await send("POST", "/v1/invites"))
        guard let invite = Invite(hubURL: Storage.shared.hubURL.value, code: response.code) else {
            throw HubError.invalidURL
        }
        return (invite, response.expiresAt)
    }

    /// The patient's data sources at the hub.
    func sources() async throws -> Sources {
        try JSONDecoder().decode(Sources.self, from: await send("GET", "/v1/patient/source"))
    }

    /// Sets the patient's sources to these settings; one that is not set is removed at
    /// the hub. Admins only; from a phone that joined with an invite only when the user
    /// confirmed the change (`confirmed`).
    func sendSources(_ sources: LocalSources, confirmed: Bool = false) async throws {
        guard !joinedWithInvite.value || confirmed else { throw HubError.invitedPhone }
        var body: [String: Any] = [:]
        if sources.hasNightscout {
            body["nightscoutUrl"] = sources.nightscoutURL
            body["token"] = sources.token
        }
        if sources.hasDexcom {
            body["dexcom"] = [
                "username": sources.dexcomUser,
                "password": sources.dexcomPassword,
                "server": sources.dexcomServer,
            ]
        }
        _ = try await send("PUT", "/v1/patient/source", body: body)
    }

    /// Asks the hub to deliver a test alarm to this device with the first enabled alarm's sound.
    func sendTestAlarm(delaySeconds: Int = 0) async throws {
        let alarm = Storage.shared.alarms.value.first(where: \.isEnabled) ?? Storage.shared.alarms.value.first
        if let alarm { await HubAlarmSounds.prepare(for: [alarm]) }
        var body: [String: Any] = ["title": "LF Hub test alarm", "delaySeconds": delaySeconds]
        if let alarm { body["sound"] = HubAlarmSounds.notificationName(for: alarm.soundFile) }
        _ = try await send("POST", "/v1/device/testalarm", body: body)
    }

    /// Turns off the alarms the hub turned off (a Temporary alarm after it
    /// fired), as LoopFollow does locally.
    private func applyHubDisabledAlarms() async throws {
        let ids = try Set((await status().device.disabledAlarmIds ?? []).compactMap { UUID(uuidString: $0) })
        guard !ids.isEmpty else { return }
        await MainActor.run {
            var alarms = Storage.shared.alarms.value
            for index in alarms.indices where ids.contains(alarms[index].id) {
                alarms[index].isEnabled = false
            }
            Storage.shared.alarms.value = alarms
        }
    }

    /// The alarm list and configuration in the app's own export format.
    func uploadAlarms() async throws {
        guard isConnected else { return }
        try await adoptIfPending()
        await HubAlarmSounds.prepare(for: Storage.shared.alarms.value)
        guard let json = AlarmSettingsExport.fromCurrentStorage().encodeToJSON() else { return }
        do {
            _ = try await send("PUT", "/v1/device/alarms", skipRepeat: true, rawBody: Data(json.utf8))
        } catch {
            // The hub holds an older alarm list: the app alarms itself until it takes this one.
            await setConfirmed(false, problems: [Problem.alarmsNotReceived])
            throw error
        }
        await MainActor.run { alarmsPending.value = false }
    }

    func uploadClientSettings() async throws {
        guard isConnected else { return }
        try await adoptIfPending()
        _ = try await send("PUT", "/v1/device/clientsettings", skipRepeat: true, body: Self.currentClientSettings())
        await MainActor.run { clientSettingsPending.value = false }
    }

    /// The stored JSON of each client setting, plus what the phone's locale
    /// decides: the time zone, the decimal separator and the time format.
    static func currentClientSettings() -> [String: Any] {
        var settings: [String: Any] = [
            "timeZone": TimeZone.current.identifier,
            "decimalSeparator": Locale.current.decimalSeparator ?? ".",
            "timeFormat": DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current) ?? "HH:mm",
        ]
        for key in clientSettingKeys {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let value = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            else { continue }
            settings[key] = value
        }
        return settings
    }

    /// Sends the current activity's push token (empty when there is none), the
    /// push-to-start token and the renewal deadline.
    func reportLiveActivity() async throws {
        #if !targetEnvironment(macCatalyst)
            guard isConnected else { return }
            let (activityToken, renewBy) = await MainActor.run {
                (LiveActivityManager.shared.currentPushToken ?? "", Storage.shared.laRenewBy.value)
            }
            var body: [String: Any] = ["activityToken": activityToken]
            let pushToStart = Storage.shared.laPushToStartToken.value
            if !pushToStart.isEmpty { body["pushToStartToken"] = pushToStart }
            if renewBy > 0 { body["renewBy"] = renewBy }
            _ = try await send("PUT", "/v1/device/liveactivity", body: body)
        #endif
    }

    /// Fire-and-forget form of `reportLiveActivity` for lifecycle callbacks.
    func reportLiveActivitySoon() {
        guard isConnected else { return }
        Task {
            do { try await reportLiveActivity() } catch {
                LogManager.shared.log(category: .hub, message: "Hub Live Activity report failed: \(error.localizedDescription)")
            }
        }
    }

    enum Health: Equatable {
        case healthy
        case unhealthy
        /// The check did not run to an answer (the app was suspended mid-request).
        case unknown
    }

    /// Why the hub cannot deliver this device's alarms.
    enum Unhealthy: Equatable {
        /// The hub did not answer properly.
        case noAnswer
        /// No push has reached this device yet.
        case noPushYet
        /// Apple rejects the APN key the hub signs this device's pushes with.
        case keyRejected
        /// Apple rejects this phone's push registration.
        case registrationRejected
        /// Pushes have been failing for `pushFailureTolerance`.
        case pushFailing
    }

    /// Why Apple rejects pushes, from APNs' answer as the hub reports it ("403 InvalidProviderToken").
    enum PushRejection: Equatable {
        case key
        case registration
        /// A failure that may pass.
        case other
    }

    static func pushRejection(_ status: String?) -> PushRejection {
        guard let status else { return .other }
        let keyReasons = ["InvalidProviderToken", "MissingProviderToken", "TopicDisallowed", "BadCertificate"]
        let registrationReasons = ["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"]
        if keyReasons.contains(where: status.contains) { return .key }
        if registrationReasons.contains(where: status.contains) || status.hasPrefix("410") { return .registration }
        return .other
    }

    /// APNs' reason for a rejected push in plain words.
    static func pushFailureReason(_ status: String) -> String {
        switch pushRejection(status) {
        case .key: return "it does not accept the APN key. Check the Key ID and key under Settings → APN."
        case .registration: return "this phone's registration is out of date. Tap Register Again in the Ready list."
        case .other: return status
        }
    }

    /// The failed push the status tells of: the last badge push's or the sounding alarm's answer.
    private static func failedPushStatus(_ device: Status.Device) -> String? {
        [device.lastPushStatus, device.activeAlarm?.lastPushStatus].compactMap { $0 }.first { !$0.hasPrefix("200") }
    }

    /// Pushes to this device may fail this long before the hub counts as unable
    /// to reach it.
    static let pushFailureTolerance: TimeInterval = 10 * 60

    /// The hub answers for this device (so its database and this device's key
    /// work), its engine is alive, and its pushes reach this device. Records the
    /// hub's confirmation from the same answer.
    func health() async -> Health {
        await healthCheck().health
    }

    /// The hub's health and, when it is unhealthy, why. A hub that does not know this
    /// device's key gives no verdict: the phone has left it.
    func healthCheck() async -> (health: Health, cause: Unhealthy?) {
        guard isConnected else { return (.unhealthy, .noAnswer) }
        do {
            let status = try await status()
            await absorb(status)
            let (_, code) = try await request("GET", "/livez", key: nil)
            guard code == 200 else { return (.unhealthy, .noAnswer) }
            let cause = Self.unhealthiness(of: status, now: Date())
            return (cause == nil ? .healthy : .unhealthy, cause)
        } catch {
            if Self.isCancellation(error) || !isConnected { return (.unknown, nil) }
            return (.unhealthy, .noAnswer)
        }
    }

    /// Healthy once a push has reached this device and while pushes have not been
    /// failing for `pushFailureTolerance`.
    static func health(of status: Status, now: Date) -> Health {
        unhealthiness(of: status, now: now) == nil ? .healthy : .unhealthy
    }

    /// Why the hub's pushes do not reach this device, or nil while they do. Apple
    /// rejecting the key or the phone's registration counts at once; any other failure
    /// after `pushFailureTolerance`.
    static func unhealthiness(of status: Status, now: Date) -> Unhealthy? {
        if let since = status.device.pushFailingSince {
            switch pushRejection(failedPushStatus(status.device)) {
            case .key: return .keyRejected
            case .registration: return .registrationRejected
            case .other: if now.timeIntervalSince(since) >= pushFailureTolerance { return .pushFailing }
            }
        }
        return status.device.lastPushOkAt == nil ? .noPushYet : nil
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// The patient's bundle, or nil when it is still `since` after waiting up to
    /// `wait` seconds for a newer one (the hub answers 304).
    func bundle(since: Int64, wait: Int) async throws -> Data? {
        guard isConnected else { throw HubError.notConnected }
        var path = "/v1/patient/bundle"
        if since > 0 { path += "?since=\(since)" + (wait > 0 ? "&wait=\(wait)" : "") }
        let (data, code) = try await request("GET", path, timeout: TimeInterval(wait + 15))
        switch code {
        case 200: return data
        case 304: return nil
        default: throw Self.httpError(code, data)
        }
    }

    /// Log files to attach to Share Logs: the hub's lines about this device and
    /// the notification service extension's log from the App Group.
    func diagnosticLogFiles() async -> [URL] {
        var files: [URL] = []
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HubLogs", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if isConnected {
            let hubLog = directory.appendingPathComponent("LF Hub.log")
            do {
                let data = try await send("GET", "/v1/device/log?hours=48")
                try data.write(to: hubLog)
                files.append(hubLog)
            } catch {
                let note = Data("Could not fetch the hub log: \(error.localizedDescription)\n".utf8)
                if (try? note.write(to: hubLog)) != nil { files.append(hubLog) }
            }
        }

        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupID.current()) {
            let extensionLog = group.appendingPathComponent("Library/Logs/lfhub-nse.log")
            let copy = directory.appendingPathComponent("LF Hub notification extension.log")
            if (try? FileManager.default.copyItem(at: extensionLog, to: copy)) != nil { files.append(copy) }
        }
        return files
    }

    /// Tells the hub the alarm was snoozed or acknowledged here, so it stops
    /// repeating it at once. The alarms with the new snooze go first, so the hub
    /// never takes the alarm as handled without its snooze.
    func alarmHandled(_ alarmID: UUID) {
        guard isHubMode else { return }
        LogManager.shared.log(category: .hub, message: "Alarm \(alarmID) handled here (connected=\(isConnected)), reporting to the hub")
        uploadSoon { client in
            try await Self.reportHandled(upload: { try await client.uploadAlarms() },
                                         handled: { _ = try await client.send("POST", "/v1/device/alarm/\(alarmID.uuidString)/handled") })
            LogManager.shared.log(category: .hub, message: "Alarm \(alarmID) reported handled to the hub")
        }
    }

    /// Uploads, then reports the alarm handled. An upload the hub refuses for good does
    /// not hold back the report; one that may pass fails the whole step, to be retried.
    static func reportHandled(upload: () async throws -> Void, handled: () async throws -> Void) async throws {
        do {
            try await upload()
        } catch let error where !isRetryable(error) {
            LogManager.shared.log(category: .hub, message: "Alarm upload before handled failed: \(error.localizedDescription)")
        }
        try await handled()
    }

    /// The alarm the hub is sounding that is the current alarm here, if any.
    @MainActor private var adoptedAlarm: UUID?

    /// Makes an alarm the hub delivered the current alarm, so the snooze action and
    /// the Snoozer act on it like on a locally fired one.
    @MainActor func adoptHubAlarm(_ alarmID: UUID) {
        adoptedAlarm = alarmID
        if Observable.shared.currentAlarm.value != alarmID {
            Observable.shared.currentAlarm.value = alarmID
        }
    }

    /// The hub no longer sounds the adopted alarm. While the hub drives the alarms it
    /// stops being the current alarm, without telling the hub it was handled; while
    /// the app alarms itself, its own check decides.
    @MainActor private func hubStoppedAlarm() {
        guard let alarmID = adoptedAlarm else { return }
        adoptedAlarm = nil
        guard drivesAlarms, Observable.shared.currentAlarm.value == alarmID else { return }
        LogManager.shared.log(category: .hub, message: "Hub alarm \(alarmID.uuidString.prefix(8)) stopped at the hub")
        Observable.shared.currentAlarm.value = nil
        Observable.shared.currentAlarmTitleOverride.value = nil
    }

    /// The hub's view of this device, recorded as a sync records it.
    func currentStatus() async throws -> Status {
        let status = try await status()
        await absorb(status)
        return status
    }

    /// Reads the hub's view of this device: whether it confirms the alarms, and
    /// whether the adopted alarm still sounds there.
    func refreshStatus() async {
        guard isConnected else { return }
        do {
            try await confirm()
        } catch HubError.http(401, _) {
            await forgotten()
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub status failed: \(error.localizedDescription)")
        }
    }

    /// Leaves the hub here at once. The device stays pending removal until the hub
    /// confirms it, so the hub stops sending to this phone.
    func disconnect() async {
        let key = deviceKey.value
        let base = Storage.shared.hubURL.value
        if !key.isEmpty, !base.isEmpty, !pendingUnregistration.keep(key: key, hubURL: base) {
            LogManager.shared.log(category: .hub, message: "The hub device key could not be kept for removal")
        }
        await localDisconnect()
        await unregisterPending()
        await retryUnregistrationWhileActive()
    }

    @MainActor private(set) var unregistrationRetry: Task<Void, Never>?
    static let unregistrationRetryInterval: UInt64 = 60

    /// Asks the hub every minute to remove the device this phone left, while one is
    /// pending and the app is active. Coming to the foreground starts it again.
    @MainActor func retryUnregistrationWhileActive() {
        guard pendingUnregistration.current != nil, unregistrationRetry == nil else { return }
        unregistrationRetry = Task { @MainActor [self] in
            while pendingUnregistration.current != nil, UIApplication.shared.applicationState == .active {
                try? await Task.sleep(nanoseconds: Self.unregistrationRetryInterval * 1_000_000_000)
                if Task.isCancelled { break }
                await unregisterPending()
            }
            if !Task.isCancelled { unregistrationRetry = nil }
        }
    }

    /// Stops asking the hub to remove the device this phone left until the next start.
    @MainActor func stopUnregistrationRetries() {
        unregistrationRetry?.cancel()
        unregistrationRetry = nil
    }

    /// Asks the hub to remove the device this phone left, if one is pending. Done once the
    /// hub removes it or no longer knows its key; otherwise tried again on a later sync.
    func unregisterPending() async {
        guard let pending = pendingUnregistration.current else { return }
        do {
            let (_, code) = try await request("DELETE", "/v1/device", baseURL: pending.hubURL, key: pending.key)
            if HubPendingUnregistration.isDone(code) {
                pendingUnregistration.clear()
                LogManager.shared.log(category: .hub, message: "Hub removed the device this phone left (\(code))")
            } else {
                LogManager.shared.log(category: .hub, message: "Hub did not remove the device this phone left: \(code)")
            }
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub removal of the device this phone left failed: \(error.localizedDescription)")
        }
    }

    /// Forgets the hub; Hub mode falls back to Silent Tune so the app alarms again.
    @MainActor private func localDisconnect() {
        deviceKey.clear()
        uploads.forget()
        shareHubURL()
        setConfirmed(false, problems: [])
        hubInfo.value = nil
        role.value = .admin
        joinedWithInvite.value = false
        apnsKeyShared.value = false
        patientName.value = ""
        sentKeyFingerprint.value = ""
        HubSourceSync.shared.forget()
        adoptionPending.value = .none
        if Storage.shared.backgroundRefreshType.value == .hub {
            BackgroundRefreshSettingsViewModel.change(to: .silentTune)
            LogManager.shared.log(category: .hub, message: "Hub disconnected; Background Refresh back to Silent Tune")
        }
        hubSettingsPending.value = false
        LogManager.shared.log(category: .hub, message: "Disconnected from hub")
    }

    /// The hub's address in the App Group while connected, for the notification
    /// service extension's delivery receipts; removed when not connected.
    private func shareHubURL() {
        let defaults = UserDefaults(suiteName: AppGroupID.current())
        let url = isConnected ? Storage.shared.hubURL.value : nil
        guard defaults?.string(forKey: HubAppGroup.hubURLKey) != url else { return }
        if let url {
            defaults?.set(url, forKey: HubAppGroup.hubURLKey)
        } else {
            defaults?.removeObject(forKey: HubAppGroup.hubURLKey)
        }
    }

    private let syncLock = NSLock()
    private var lastSync: Task<Void, Never>?

    /// Brings the hub up to date with this device: APNs registration and the
    /// settings the hub acts on. Safe to call often; calls run one after another.
    func sync() async {
        let task = syncLock.withLock {
            let previous = lastSync
            let next = Task { [self] in
                await previous?.value
                await performSync()
            }
            lastSync = next
            return next
        }
        await task.value
    }

    private func performSync() async {
        shareHubURL()
        await unregisterPending()
        guard isConnected else { return }
        // In Hub mode the open app long-polls the hub and runs the watchdog's check.
        await MainActor.run {
            if UIApplication.shared.applicationState == .active { HubBundle.shared.startListening() }
        }
        do {
            try await registerApns()
            try await reportLiveActivity()
            try await uploadClientSettings()
            if isHubMode || alarmsPending.value {
                try await applyHubDisabledAlarms()
                try await uploadAlarms()
            }
        } catch HubError.http(401, _) {
            await forgotten()
            return
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub sync failed: \(error.localizedDescription)")
        }

        // What the hub drives goes even after a failed step: leaving Hub mode must
        // reach the hub, or both would alarm.
        do {
            try await pushHubSettings()
        } catch HubError.http(401, _) {
            await forgotten()
        } catch {
            LogManager.shared.log(category: .hub, message: "Hub settings push failed: \(error.localizedDescription)")
            uploadSoon { try await $0.pushHubSettings() }
        }
    }

    /// The hub answered 401 to this phone's key: the phone was replaced or removed. Leaves
    /// the hub at once, so the app alarms itself again, and tells the user once.
    @MainActor private func forgotten() {
        guard isConnected else { return }
        LogManager.shared.log(category: .hub, message: "Hub no longer knows this device")
        localDisconnect()
        removedFromHub.value = true
        let content = UNMutableNotificationContent()
        content.title = "This phone was removed from LF Hub"
        content.body = "LoopFollow alarms by itself again. To use LF Hub, join again under Settings → LF Hub."
        content.sound = .default
        postNotification(UNNotificationRequest(identifier: "lfhub.removed", content: content, trigger: nil))
    }

    /// Delivers the app's own notices; tests replace it.
    @MainActor var postNotification: (UNNotificationRequest) -> Void = { UNUserNotificationCenter.current().add($0) }

    /// Tells the hub what it drives for this device and records its confirmation.
    /// The badge and the Live Activity follow their settings in this app.
    private func pushHubSettings() async throws {
        _ = try await send("PUT", "/v1/device/settings", skipRepeat: true,
                           body: ["badge": isHubMode && Storage.shared.appBadge.value,
                                  "liveActivity": isHubMode && Storage.shared.laEnabled.value,
                                  "alarms": isHubMode,
                                  "unit": unit,
                                  "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                                  "features": Self.features] as [String: Any])
        await MainActor.run { hubSettingsPending.value = false }
        try await confirm()
    }

    /// Reads the hub's view of this device and records whether it delivers the alarms.
    private func confirm() async throws {
        try await absorb(await status())
    }

    /// Records the hub's answer and takes a newer revision of the patient's data sources.
    private func absorb(_ status: Status) async {
        await record(status)
        await HubSourceSync.shared.follow(status)
    }

    /// Records whether the hub's status confirms this device's alarms, and why not.
    /// While it confirms, the alarm the hub is sounding becomes the current alarm, so
    /// the in-app snooze acts on it; an adopted alarm the hub no longer sounds is let go.
    @MainActor private func record(_ status: Status) {
        if hubInfo.value != status.hub { hubInfo.value = status.hub }
        role.value = Self.role(reported: status.device.role, joinedWithInvite: joinedWithInvite.value)
        apnsKeyShared.value = status.device.apnsKeyShared == true
        patientName.value = status.patient.name
        guard isHubMode else {
            setConfirmed(false, problems: [])
            return
        }
        let problems = Self.confirmationProblems(status, alarmsPending: alarmsPending.value || adoptionPending.value != .none,
                                                 alarmKitAuthorized: Self.alarmKitAuthorized,
                                                 notificationsAllowed: notificationsAllowed.value, now: Date(),
                                                 exportedAlarms: Self.alarmCountForHub(Storage.shared.alarms.value,
                                                                                       hubAPI: status.hub?.api))
        setConfirmed(problems.isEmpty, problems: problems)
        if let alarmID = status.device.activeAlarm?.alarmId.flatMap(UUID.init(uuidString:)) {
            if problems.isEmpty { adoptHubAlarm(alarmID) }
        } else {
            hubStoppedAlarm()
        }
    }

    /// Whether the hub's status shows it delivering this device's alarms.
    static func confirms(_ status: Status, hubMode: Bool, alarmsPending: Bool, alarmKitAuthorized: Bool,
                         notificationsAllowed: Bool, now: Date, exportedAlarms: Int? = nil) -> Bool
    {
        hubMode && confirmationProblems(status, alarmsPending: alarmsPending, alarmKitAuthorized: alarmKitAuthorized,
                                        notificationsAllowed: notificationsAllowed, now: now,
                                        exportedAlarms: exportedAlarms).isEmpty
    }

    /// What keeps the hub from delivering this device's alarms, in words for the user.
    enum Problem {
        static let noPush = "The hub cannot notify this phone yet. Add the APN key under Settings → APN and allow notifications."
        static let alarmsOff = "Alarms are not on at the hub yet."
        static let alarmsNotReceived = "The hub does not have this phone's latest alarms yet."
        static let notFollowed = "The hub is not reading the patient's data yet. Check the data sources under Settings → LF Hub."
        static let noPushYet = "No notification from the hub has arrived yet."
        static let pushFailing = "Notifications from LF Hub are not reaching this phone."
        static let apnKeyRejected = "Apple rejects the APN key, so LF Hub cannot notify this phone."
        static let alarmsSkipped = "LF Hub could not read some of this phone's alarms, so LoopFollow checks the alarms itself. Updating LF Hub may help."
        static let alarmKitDenied = "Alarms may not ring through silent mode. Allow it under Settings → LF Hub."
        static let alarmKitUnavailable = "Ringing through silent mode requires iOS 26."
        static let notificationsOff = "Notifications for LoopFollow are off or delivered quietly, so LF Hub's alarms would not show."
        static let hubOutdated = "The hub needs an update to work with this LoopFollow."
    }

    /// Whether the hub speaks this app's API version and provides what this app requires.
    static func supports(_ hub: Status.Hub?) -> Bool {
        guard let hub, hub.api >= api else { return false }
        return requiredHubFeatures.allSatisfy(hub.features.contains)
    }

    /// Each reason the status gives for the hub not delivering this device's alarms:
    /// a hub version this app does not work with, push not registered or not reaching the
    /// phone, alarms off at the hub, the latest alarm list not received or fewer alarms in
    /// it than the `exportedAlarms` the hub should hold, the patient not followed, AlarmKit
    /// not allowed, or notifications not allowed.
    static func confirmationProblems(_ status: Status, alarmsPending: Bool, alarmKitAuthorized: Bool,
                                     notificationsAllowed: Bool, now: Date, exportedAlarms: Int? = nil) -> [String]
    {
        var problems: [String] = []
        if !supports(status.hub) { problems.append(Problem.hubOutdated) }
        if !status.device.apnsConfigured { problems.append(Problem.noPush) }
        if status.device.settings?.alarms != true { problems.append(Problem.alarmsOff) }
        if alarmsPending || status.device.alarmsReceived != true {
            problems.append(Problem.alarmsNotReceived)
        } else if let exportedAlarms, let held = status.device.alarmCount, held < exportedAlarms {
            problems.append(Problem.alarmsSkipped)
        }
        if status.patient.followed != true { problems.append(Problem.notFollowed) }
        if status.device.apnsConfigured, let cause = unhealthiness(of: status, now: now) {
            problems.append(problem(for: cause))
        }
        if let problem = alarmKitProblem(authorized: alarmKitAuthorized) { problems.append(problem) }
        if !notificationsAllowed { problems.append(Problem.notificationsOff) }
        return problems
    }

    /// The words for the user for a push problem.
    static func problem(for cause: Unhealthy) -> String {
        switch cause {
        case .noPushYet: return Problem.noPushYet
        case .keyRejected: return Problem.apnKeyRejected
        case .noAnswer, .registrationRejected, .pushFailing: return Problem.pushFailing
        }
    }

    /// Why hub alarms cannot ring as system alarms, if they cannot.
    static func alarmKitProblem(authorized: Bool) -> String? {
        guard !authorized else { return nil }
        if #available(iOS 26, *) { return Problem.alarmKitDenied }
        return Problem.alarmKitUnavailable
    }

    /// AlarmKit lets the hub's alarms ring as system alarms, through silent mode.
    static var alarmKitAuthorized: Bool {
        #if !targetEnvironment(macCatalyst)
            if #available(iOS 26, *) { return HubAlarmKit.isAuthorized }
        #endif
        return false
    }

    @MainActor private func setConfirmed(_ confirmed: Bool, problems: [String]) {
        let wasDriving = drivesAlarms
        if confirmed != hubConfirmed.value || problems != hubProblems.value {
            LogManager.shared.log(category: .hub, message: confirmed
                ? "Hub confirmed it delivers this device's alarms"
                : "Hub does not deliver this device's alarms; the app keeps alarming. \(problems.joined(separator: " "))")
        }
        hubConfirmed.value = confirmed
        hubProblems.value = problems
        // In the background the app now keeps itself running, as in Silent Tune.
        if wasDriving, !drivesAlarms { MainViewController.shared?.backgroundModeChanged() }
    }

    /// The key the hub pushes to this device with.
    enum ApnsKeyUse: Equatable {
        /// This app's own key; the .p8 goes along only when `sendKey`.
        case own(keyId: String, sendKey: Bool)
        /// An admin device's key, which the hub shares with this device.
        case shared
        /// No key yet.
        case none
    }

    /// This app's own key when it has one and may send it, otherwise an admin's on a hub
    /// that shares keys. The .p8 goes only when it changed since the hub last took it.
    static func apnsKeyUse(keyId: String, key: String, sentFingerprint: String, hubSharesKeys: Bool,
                           ownKeyAllowed: Bool = true) -> ApnsKeyUse
    {
        if ownKeyAllowed, !keyId.isEmpty, !key.isEmpty {
            return .own(keyId: keyId, sendKey: sentFingerprint != keyFingerprint(keyId: keyId, key: key))
        }
        return hubSharesKeys ? .shared : .none
    }

    static func keyFingerprint(keyId: String, key: String) -> String {
        SHA256.hash(data: Data((keyId + key).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func registerApns() async throws {
        let token = Observable.shared.loopFollowDeviceToken.value
        let keyId = Storage.shared.lfKeyId.value
        let key = Storage.shared.lfApnsKey.value
        let use = Self.apnsKeyUse(keyId: keyId, key: key, sentFingerprint: sentKeyFingerprint.value,
                                  hubSharesKeys: offers("sharedApnsKey"), ownKeyAllowed: !joinedWithInvite.value)
        guard !token.isEmpty, use != .none, let teamId = BuildDetails.default.teamID,
              let bundleId = Bundle.main.bundleIdentifier
        else {
            LogManager.shared.log(category: .hub, message: "Hub APNs registration waits for the device token and APN key", isDebug: true)
            return
        }
        var body = [
            "token": token,
            "environment": BuildDetails.default.isTestFlightBuild() ? "production" : "sandbox",
            "bundleId": bundleId,
            "teamId": teamId,
        ]
        switch use {
        case .none:
            return
        case .shared:
            do {
                _ = try await send("PUT", "/v1/device/apns", body: body)
            } catch let HubError.http(400, message) {
                // No admin device has a key to share; the rest of the sync goes on.
                LogManager.shared.log(category: .hub, message: "Hub APNs registration without a key refused: \(message)")
                await MainActor.run { apnsKeyShared.value = false }
                return
            }
            await MainActor.run { sentKeyFingerprint.value = "" }
        case let .own(keyId, sendKey):
            body["keyId"] = keyId
            if sendKey { body["key"] = key }
            do {
                _ = try await send("PUT", "/v1/device/apns", body: body)
            } catch HubError.http(400, _) where body["key"] == nil {
                body["key"] = key
                _ = try await send("PUT", "/v1/device/apns", body: body)
            }
            await MainActor.run { sentKeyFingerprint.value = Self.keyFingerprint(keyId: keyId, key: key) }
        }
    }

    /// Registers this phone for notifications again and sends the hub the registration
    /// with the APN key.
    func registerAgain() async {
        await MainActor.run {
            sentKeyFingerprint.value = ""
            UIApplication.shared.registerForRemoteNotifications()
        }
        LogManager.shared.log(category: .hub, message: "Registering for the hub's notifications again")
        await sync()
    }

    // MARK: - Transport

    private var unit: String {
        UnitSettingsStore.shared.glucoseUnit == .mmolL ? "mmol" : "mgdl"
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = fractional.date(from: string) ?? plain.date(from: string) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(string)"))
        }
        return decoder
    }()

    /// The uploads that reached the hub lately, so the same upload made again right after
    /// (two syncs in a row, a snooze and its debounced upload) is not sent twice.
    private let uploads = RecentUploads()

    /// The response body of a call answered with 2xx; any other answer throws. With
    /// `skipRepeat` an upload the hub took within `RecentUploads.window` is not sent again,
    /// and answers an empty body.
    private func send(_ method: String, _ path: String, skipRepeat: Bool = false, body: Any? = nil,
                      rawBody: Data? = nil, baseURL: String = Storage.shared.hubURL.value,
                      key: String? = HubClient.shared.deviceKey.value) async throws -> Data
    {
        let upload = skipRepeat ? RecentUploads.digest(body: body, rawBody: rawBody) : nil
        if let upload, uploads.isRepeat(path, upload, now: Date()) {
            LogManager.shared.log(category: .hub, message: "Hub upload \(path) skipped: the hub took the same just now", isDebug: true)
            return Data()
        }
        let (data, code) = try await request(method, path, body: body, rawBody: rawBody, baseURL: baseURL, key: key)
        guard (200 ..< 300).contains(code) else { throw Self.httpError(code, data) }
        if let upload { uploads.record(path, upload, now: Date()) }
        return data
    }

    /// The response body of a GET answered with 200, or nil when the hub answered 404.
    private func optionalData(_ path: String) async throws -> Data? {
        let (data, code) = try await request("GET", path)
        switch code {
        case 200: return data
        case 404: return nil
        default: throw Self.httpError(code, data)
        }
    }

    private static func httpError(_ code: Int, _ data: Data) -> HubError {
        let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
        return HubError.http(code, detail ?? HTTPURLResponse.localizedString(forStatusCode: code))
    }

    /// The response body and status code of a call; `key` nil sends no key.
    private func request(_ method: String, _ path: String, body: Any? = nil, rawBody: Data? = nil,
                         baseURL: String = Storage.shared.hubURL.value,
                         key: String? = HubClient.shared.deviceKey.value,
                         timeout: TimeInterval = 15) async throws -> (Data, Int)
    {
        if let key, key.isEmpty { throw HubError.notConnected }
        guard let url = URL(string: baseURL + path), url.scheme == "https" || url.scheme == "http" else {
            throw HubError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let key { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else if let rawBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = rawBody
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        // Any call with this phone's key answered 401: the hub does not know the phone.
        if code == 401, let key, key == deviceKey.value { await forgotten() }
        return (data, code)
    }
}

/// The uploads the hub took lately, by path, as a digest of their body.
final class RecentUploads {
    /// The same upload within this long after the last is skipped.
    static let window: TimeInterval = 30

    private let lock = NSLock()
    private var taken: [String: (digest: String, at: Date)] = [:]

    /// A digest of the body that does not depend on the order of its keys; nil when it
    /// is not JSON.
    static func digest(body: Any?, rawBody: Data?) -> String? {
        let object: Any? = body ?? rawBody.flatMap { try? JSONSerialization.jsonObject(with: $0) }
        guard let object,
              let canonical = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return nil }
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }

    func isRepeat(_ path: String, _ digest: String, now: Date) -> Bool {
        lock.withLock {
            guard let last = taken[path] else { return false }
            return last.digest == digest && now.timeIntervalSince(last.at) < Self.window
        }
    }

    func record(_ path: String, _ digest: String, now: Date) {
        lock.withLock { taken[path] = (digest, now) }
    }

    func forget() {
        lock.withLock { taken = [:] }
    }
}

extension HubClient.Join {
    var logDescription: String {
        switch self {
        case .new: return "new device"
        case let .replace(id): return "replacing device \(id.uuidString.prefix(8))"
        case let .copy(id): return "copying device \(id.uuidString.prefix(8))"
        }
    }
}

/// A stored value sent to the hub as a client setting, and taken back from it.
protocol ClientSetting: AnyObject {
    var key: String { get }
    /// Sets the value from its JSON; false when the JSON is not of the value's type.
    func assign(json: Data) -> Bool
}

extension StorageValue: ClientSetting {
    func assign(json: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode(T.self, from: json) else { return false }
        value = decoded
        return true
    }
}
