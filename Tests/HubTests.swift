// LoopFollow
// HubTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct HubBundleTests {
    private func bundle(version: Int64, parts: [String: Any?]) -> Data {
        var encoded: [String: Any] = [:]
        for (name, data) in parts {
            encoded[name] = ["fetchedAt": "2026-01-01T00:00:00Z", "data": data ?? NSNull()]
        }
        return try! JSONSerialization.data(withJSONObject: ["version": version, "parts": encoded])
    }

    @Test("a first bundle reports every part it carries and stores the version")
    func firstBundle() {
        let hub = HubBundle()
        let changed = hub.apply(bundle(version: 3, parts: [
            "entries": [["sgv": 100, "date": 1_700_000_000_000, "direction": "Flat"]],
            "profile": [["defaultProfile": "Default"]],
        ]))

        #expect(changed == [.entries, .profile])
        #expect(hub.version == 3)
        #expect(hub.stored(.entries) != nil)
        #expect(hub.stored(.treatments) == nil)
    }

    @Test("parts are used only while the hub answered recently")
    func staleParts() {
        let hub = HubBundle()
        let received = Date(timeIntervalSince1970: 1_700_000_000)
        _ = hub.apply(bundle(version: 1, parts: ["profile": [["defaultProfile": "Default"]]]), receivedAt: received)

        #expect(hub.current(.profile, now: received.addingTimeInterval(HubBundle.staleAfter - 1)) != nil)
        #expect(hub.current(.profile, now: received.addingTimeInterval(HubBundle.staleAfter)) == nil)
        #expect(hub.stored(.profile) != nil)
    }

    @Test("an unchanged part is not reported again")
    func unchangedPart() {
        let hub = HubBundle()
        let profile: [[String: Any]] = [["defaultProfile": "Default"]]
        _ = hub.apply(bundle(version: 1, parts: ["profile": profile, "dbsize": ["dataSize": 1]]))

        let changed = hub.apply(bundle(version: 2, parts: ["profile": profile, "dbsize": ["dataSize": 2]]))

        #expect(changed == [.dbsize])
        #expect(hub.version == 2)
    }

    @Test("a null part and an unknown part are skipped")
    func skippedParts() {
        let hub = HubBundle()
        let changed = hub.apply(bundle(version: 1, parts: ["sage": nil, "somethingNew": [1, 2]]))

        #expect(changed.isEmpty)
        #expect(hub.stored(.sage) == nil)
    }

    @Test("a response that does not parse changes nothing")
    func unparsable() {
        let hub = HubBundle()
        #expect(hub.apply(Data("not json".utf8)).isEmpty)
        #expect(hub.version == 0)
    }

    @Test("a part is current only in Hub mode and while the hub answered recently")
    func currentPart() {
        let received = Date(timeIntervalSince1970: 1_700_000_000)
        let active = HubBundle(isActive: { true })
        _ = active.apply(bundle(version: 1, parts: ["entries": [["sgv": 100]]]), receivedAt: received)
        #expect(active.hasCurrent(.entries, now: received.addingTimeInterval(60)))
        #expect(!active.hasCurrent(.entries, now: received.addingTimeInterval(HubBundle.staleAfter)))
        #expect(!active.hasCurrent(.profile, now: received.addingTimeInterval(60)))

        let inactive = HubBundle(isActive: { false })
        _ = inactive.apply(bundle(version: 1, parts: ["entries": [["sgv": 100]]]), receivedAt: received)
        #expect(!inactive.hasCurrent(.entries, now: received.addingTimeInterval(60)))
    }

    @Test("a current part is handed out as is, and outside Hub mode none is")
    func dataForPart() async {
        let active = HubBundle(isActive: { true })
        _ = active.apply(bundle(version: 1, parts: ["profile": [["defaultProfile": "Default"]]]))
        #expect(await active.data(for: .profile) == active.stored(.profile))

        let inactive = HubBundle(isActive: { false })
        _ = inactive.apply(bundle(version: 1, parts: ["profile": [["defaultProfile": "Default"]]]))
        #expect(await inactive.data(for: .profile) == nil)
    }

    @Test("each part reruns the task that reads it")
    func partTasks() {
        #expect(HubBundle.Part.entries.task == .fetchBG)
        #expect(HubBundle.Part.devicestatus.task == .deviceStatus)
        #expect(HubBundle.Part.profile.task == .profile)
        #expect(HubBundle.Part.dbsize.task == .dbSize)
        for part in [HubBundle.Part.treatments, .sage, .cage, .iage] {
            #expect(part.task == .treatments)
        }
    }
}

struct HubModeTests {
    @Test("only modes that keep the app running are watched for stalls")
    func keepsAppRunning() {
        #expect(BackgroundRefreshType.silentTune.keepsAppRunning)
        #expect(BackgroundRefreshType.dexcom.keepsAppRunning)
        #expect(!BackgroundRefreshType.hub.keepsAppRunning)
        #expect(!BackgroundRefreshType.none.keepsAppRunning)
        #expect(!BackgroundRefreshType.hub.isBluetooth)
    }

    @Test("converted alarm sounds have stable names the hub can address")
    func notificationSoundNames() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000AB")!
        #expect(HubAlarmSounds.notificationName(for: .builtin("Indeed")) == "lfhub-Indeed.caf")
        #expect(HubAlarmSounds.notificationName(for: .custom(id)) == "lfhub-\(id.uuidString).caf")
    }

    @Test("client settings always carry the phone's locale facts")
    func clientSettings() {
        let settings = HubClient.currentClientSettings()
        #expect(settings["timeZone"] as? String == TimeZone.current.identifier)
        #expect(settings["decimalSeparator"] is String)
        #expect(settings["timeFormat"] is String)
        for key in settings.keys where !["timeZone", "decimalSeparator", "timeFormat"].contains(key) {
            #expect(HubClient.clientSettingKeys.contains(key))
        }
    }
}

struct HubHealthTests {
    private func status(pushFailingSince: String? = nil, lastPushOkAt: String? = "2026-01-01T11:59:30.123456Z",
                        apnsConfigured: Bool = true, alarmsOn: Bool = true, alarmsReceived: Bool = true,
                        followed: Bool = true,
                        hub: [String: Any]? = ["version": "1.0.0", "api": 1, "features": ["receipts", "speak"]]) throws
        -> HubClient.Status
    {
        var device: [String: Any] = [
            "name": "Phone", "apnsConfigured": apnsConfigured,
            "liveActivity": ["registered": true, "pushToStartRegistered": true, "renewalFailed": false],
            "settings": ["alarms": alarmsOn],
            "alarmsReceived": alarmsReceived,
        ]
        if let pushFailingSince { device["pushFailingSince"] = pushFailingSince }
        if let lastPushOkAt { device["lastPushOkAt"] = lastPushOkAt }
        var json: [String: Any] = [
            "device": device,
            "patient": ["name": "Patient", "followed": followed],
            "live": ["connected": true, "staleAfterSeconds": 600],
        ]
        if let hub { json["hub"] = hub }
        return try HubClient.decoder.decode(HubClient.Status.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private let now = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!

    private func confirms(_ status: HubClient.Status, hubMode: Bool = true, alarmsPending: Bool = false,
                          alarmKitAuthorized: Bool = true, notificationsAllowed: Bool = true) -> Bool
    {
        HubClient.confirms(status, hubMode: hubMode, alarmsPending: alarmsPending,
                           alarmKitAuthorized: alarmKitAuthorized, notificationsAllowed: notificationsAllowed, now: now)
    }

    @Test("the hub's dates decode with and without fractional seconds")
    func dates() throws {
        let decoded = try status(pushFailingSince: "2026-01-01T11:55:00Z")
        #expect(decoded.device.pushFailingSince == ISO8601DateFormatter().date(from: "2026-01-01T11:55:00Z"))
        #expect(decoded.device.lastPushOkAt != nil)
    }

    @Test("a hub whose pushes reach the device is healthy")
    func pushesWork() throws {
        #expect(try HubClient.health(of: status(pushFailingSince: nil), now: now) == .healthy)
    }

    @Test("a hub that never reached the device is not healthy")
    func neverPushed() throws {
        #expect(try HubClient.health(of: status(lastPushOkAt: nil), now: now) == .unhealthy)
    }

    @Test("pushes failing for a short while are tolerated")
    func briefPushFailure() throws {
        #expect(try HubClient.health(of: status(pushFailingSince: "2026-01-01T11:55:00Z"), now: now) == .healthy)
    }

    @Test("pushes failing for ten minutes make the hub unhealthy")
    func lastingPushFailure() throws {
        #expect(try HubClient.health(of: status(pushFailingSince: "2026-01-01T11:50:00Z"), now: now) == .unhealthy)
    }

    @Test("the hub confirms a device's alarms when everything is in place")
    func confirmed() throws {
        #expect(try confirms(status()))
        #expect(try HubClient.confirmationProblems(status(), alarmsPending: false, alarmKitAuthorized: true,
                                                   notificationsAllowed: true, now: now).isEmpty)
    }

    @Test("a hub without the version exchange or without receipts is not confirmed")
    func hubVersion() throws {
        #expect(try !confirms(status(hub: nil)))
        #expect(try !confirms(status(hub: ["version": "0.9", "api": 1, "features": ["speak"]])))
        #expect(try !confirms(status(hub: ["version": "0.9", "api": 0, "features": ["receipts"]])))
        #expect(try confirms(status(hub: ["version": "2.0", "api": 2, "features": ["receipts", "somethingNew"]])))
        #expect(try HubClient.confirmationProblems(status(hub: nil), alarmsPending: false, alarmKitAuthorized: true,
                                                   notificationsAllowed: true, now: now)
                == [HubClient.Problem.hubOutdated])
    }

    @Test("any missing piece leaves the app alarming itself")
    func notConfirmed() throws {
        #expect(try !confirms(status(), hubMode: false))
        #expect(try !confirms(status(), alarmsPending: true))
        #expect(try !confirms(status(), alarmKitAuthorized: false))
        #expect(try !confirms(status(), notificationsAllowed: false))
        #expect(try !confirms(status(apnsConfigured: false)))
        #expect(try !confirms(status(alarmsOn: false)))
        #expect(try !confirms(status(alarmsReceived: false)))
        #expect(try !confirms(status(followed: false)))
        #expect(try !confirms(status(lastPushOkAt: nil)))
        #expect(try !confirms(status(pushFailingSince: "2026-01-01T11:40:00Z")))
    }

    @Test("each missing piece is named for the user")
    func problems() throws {
        func problems(_ status: HubClient.Status, alarmsPending: Bool = false, alarmKitAuthorized: Bool = true,
                      notificationsAllowed: Bool = true) -> [String]
        {
            HubClient.confirmationProblems(status, alarmsPending: alarmsPending, alarmKitAuthorized: alarmKitAuthorized,
                                           notificationsAllowed: notificationsAllowed, now: now)
        }
        #expect(try problems(status(lastPushOkAt: nil, apnsConfigured: false)) == [HubClient.Problem.noPush])
        #expect(try problems(status(alarmsOn: false)) == [HubClient.Problem.alarmsOff])
        #expect(try problems(status(alarmsReceived: false)) == [HubClient.Problem.alarmsNotReceived])
        #expect(try problems(status(), alarmsPending: true) == [HubClient.Problem.alarmsNotReceived])
        #expect(try problems(status(followed: false)) == [HubClient.Problem.notFollowed])
        #expect(try problems(status(lastPushOkAt: nil)) == [HubClient.Problem.noPushYet])
        #expect(try problems(status(pushFailingSince: "2026-01-01T11:40:00Z")) == [HubClient.Problem.pushFailing])
        #expect(try problems(status(), alarmKitAuthorized: false) == [HubClient.alarmKitProblem(authorized: false)!])
        #expect(try problems(status(), notificationsAllowed: false) == [HubClient.Problem.notificationsOff])
    }

    @Test("a cancelled request gives no verdict")
    func cancellation() {
        #expect(HubClient.isCancellation(CancellationError()))
        #expect(HubClient.isCancellation(URLError(.cancelled)))
        #expect(!HubClient.isCancellation(URLError(.timedOut)))
    }

    @Test("uploads are retried only when the failure may pass")
    func retries() {
        #expect(HubClient.isRetryable(URLError(.timedOut)))
        #expect(HubClient.isRetryable(HubClient.HubError.http(503, "")))
        #expect(HubClient.isRetryable(HubClient.HubError.http(429, "")))
        #expect(!HubClient.isRetryable(HubClient.HubError.http(400, "")))
        #expect(!HubClient.isRetryable(HubClient.HubError.http(409, "")))
        #expect(!HubClient.isRetryable(HubClient.HubError.notConnected))
    }
}

struct HubWatchdogTests {
    private typealias State = HubWatchdog.State
    private let start: TimeInterval = 1_700_000_000

    @Test("outside Hub mode the watchdog forgets everything and clears its alert")
    func leavingHubMode() {
        let alerted = State(lastHealthy: start, unhealthySince: start + 60, alerted: true)
        #expect(HubWatchdog.next(alerted, hubMode: false, health: .unhealthy, now: start + 120) == (State(), .clearAlert))
        #expect(HubWatchdog.next(State(), hubMode: false, health: .healthy, now: start) == (State(), .none))
    }

    @Test("a check without an answer changes nothing")
    func unknown() {
        let state = State(lastHealthy: start, unhealthySince: start + 60, alerted: false)
        #expect(HubWatchdog.next(state, hubMode: true, health: .unknown, now: start + 3600) == (state, .none))
    }

    @Test("the first unhealthy check starts the clock")
    func firstUnhealthy() {
        let (state, action) = HubWatchdog.next(State(), hubMode: true, health: .unhealthy, now: start)
        #expect(state == State(lastHealthy: start, unhealthySince: start, alerted: false))
        #expect(action == .none)
    }

    @Test("one alert after twenty minutes without a healthy answer, then quiet")
    func alertOncePerOutage() {
        var state = State(lastHealthy: start, unhealthySince: 0, alerted: false)
        var action: HubWatchdog.Action
        (state, action) = HubWatchdog.next(state, hubMode: true, health: .unhealthy, now: start + 60)
        #expect(action == .none)
        (state, action) = HubWatchdog.next(state, hubMode: true, health: .unhealthy, now: start + HubWatchdog.silentAfter - 1)
        #expect(action == .none)
        (state, action) = HubWatchdog.next(state, hubMode: true, health: .unhealthy, now: start + HubWatchdog.silentAfter)
        #expect(action == .raiseAlert(minutes: 20))
        (state, action) = HubWatchdog.next(state, hubMode: true, health: .unhealthy, now: start + 2 * HubWatchdog.silentAfter)
        #expect(action == .none)
        #expect(state.alerted)
    }

    @Test("a healthy answer clears the alert and the clock")
    func recovery() {
        let alerted = State(lastHealthy: start, unhealthySince: start + 60, alerted: true)
        let (state, action) = HubWatchdog.next(alerted, hubMode: true, health: .healthy, now: start + 3600)
        #expect(state == State(lastHealthy: start + 3600, unhealthySince: 0, alerted: false))
        #expect(action == .clearAlert)
    }

    @Test("the app takes over its alarms after five minutes of failed checks")
    func looksHealthy() {
        #expect(HubWatchdog.looksHealthy(State(), now: start))
        let failing = State(lastHealthy: start, unhealthySince: start, alerted: false)
        #expect(HubWatchdog.looksHealthy(failing, now: start + HubWatchdog.unhealthyTolerance - 1))
        #expect(!HubWatchdog.looksHealthy(failing, now: start + HubWatchdog.unhealthyTolerance))
    }
}

/// Answers every request to `host` with 401.
final class HubUnauthorizedProtocol: URLProtocol {
    static let host = "hub.lfhub-tests.invalid"

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// These tests change HubClient.shared's connection. Notices go nowhere, and the work
/// leaving a hub starts in the background (the bundle's long poll, removal retries)
/// stops after each test, so none reaches into the next.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct HubForgottenTests {
    init() async {
        await MainActor.run { HubClient.shared.postNotification = { _ in } }
    }

    /// Stops what leaving or joining a hub left running.
    static func stopBackgroundWork() async {
        await MainActor.run {
            HubBundle.shared.stopListening()
            HubClient.shared.stopUnregistrationRetries()
        }
    }

    @Test("a hub that no longer knows the device disconnects it and Hub mode falls back to Silent Tune")
    func forgotten() async throws {
        let storage = Storage.shared
        let deviceKey = HubClient.shared.deviceKey
        let saved = (storage.hubURL.value, deviceKey.store, storage.backgroundRefreshType.value)
        deviceKey.store = MemoryKeyStore()
        URLProtocol.registerClass(HubUnauthorizedProtocol.self)
        defer {
            URLProtocol.unregisterClass(HubUnauthorizedProtocol.self)
            storage.hubURL.value = saved.0
            deviceKey.store = saved.1
            deviceKey.reload()
            storage.backgroundRefreshType.value = saved.2
        }
        try await MainActor.run {
            storage.hubURL.value = "https://\(HubUnauthorizedProtocol.host)"
            try deviceKey.set("lfh_test")
            storage.backgroundRefreshType.value = .hub
        }

        await HubClient.shared.sync()

        // Leaving the hub runs on the main actor, also when the app's own fetch met the 401 first.
        await MainActor.run {
            #expect(deviceKey.value.isEmpty)
            #expect(storage.backgroundRefreshType.value == .silentTune)
            #expect(!HubClient.shared.hubConfirmed.value)
        }
        await Self.stopBackgroundWork()
    }
}

/// Answers every request to `host` with 503, as a hub that is down.
final class HubUnavailableProtocol: URLProtocol {
    static let host = "down.lfhub-tests.invalid"

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Leaving the hub changes HubClient.shared's connection, so these run in the same
/// serialized suite as the other tests that do.
extension HubForgottenTests {
    @Test("a disconnect the hub does not confirm leaves at once and is retried until the hub removes the device")
    func unconfirmedDisconnect() async throws {
        let storage = Storage.shared
        let client = HubClient.shared
        let saved = (storage.hubURL.value, client.deviceKey.store, client.pendingUnregistration.store,
                     storage.backgroundRefreshType.value)
        client.deviceKey.store = MemoryKeyStore()
        client.pendingUnregistration.store = MemoryKeyStore()
        URLProtocol.registerClass(HubUnavailableProtocol.self)
        URLProtocol.registerClass(HubUnauthorizedProtocol.self)
        defer {
            URLProtocol.unregisterClass(HubUnavailableProtocol.self)
            URLProtocol.unregisterClass(HubUnauthorizedProtocol.self)
            client.pendingUnregistration.clear()
            client.pendingUnregistration.store = saved.2
            storage.hubURL.value = saved.0
            client.deviceKey.store = saved.1
            client.deviceKey.reload()
            storage.backgroundRefreshType.value = saved.3
        }
        try await MainActor.run {
            storage.hubURL.value = "https://\(HubUnavailableProtocol.host)"
            try client.deviceKey.set("lfh_left")
            storage.backgroundRefreshType.value = .silentTune
        }

        await client.disconnect()
        #expect(!client.isConnected)
        #expect(client.deviceKey.value.isEmpty)
        #expect(client.pendingUnregistration.current?.key == "lfh_left")
        #expect(client.pendingUnregistration.current?.hubURL == "https://\(HubUnavailableProtocol.host)")

        await client.unregisterPending()
        #expect(client.pendingUnregistration.current?.key == "lfh_left")

        // The hub no longer knows the key: the device is gone.
        client.pendingUnregistration.keep(key: "lfh_left", hubURL: "https://\(HubUnauthorizedProtocol.host)")
        await client.unregisterPending()
        #expect(client.pendingUnregistration.current == nil)
        await Self.stopBackgroundWork()
    }

    @Test("a phone that joined with an invite does not send its own data sources, whatever its role")
    func invitedPhoneSendsNoSources() async {
        let client = HubClient.shared
        let saved = (client.joinedWithInvite.value, client.role.value)
        defer {
            client.joinedWithInvite.value = saved.0
            client.role.value = saved.1
        }
        client.joinedWithInvite.value = true
        client.role.value = .admin
        await #expect(throws: HubClient.HubError.self) {
            try await client.sendSources(LocalSources(nightscoutURL: "https://ns.example.com", token: "t"))
        }
    }
}

struct HubPendingUnregistrationTests {
    @Test("a pending removal is kept with the hub's address and cleared")
    func keepAndClear() {
        let url = StorageValue<String>(key: "hubPendingUnregistrationURLTest", defaultValue: "")
        defer { url.remove() }
        let pending = HubPendingUnregistration(store: MemoryKeyStore(), hubURL: url)
        #expect(pending.current == nil)

        #expect(pending.keep(key: "lfh_old", hubURL: "https://hub.example.com"))
        #expect(pending.current?.key == "lfh_old")
        #expect(pending.current?.hubURL == "https://hub.example.com")

        pending.clear()
        #expect(pending.current == nil)
    }

    @Test("a key the store does not take is not kept")
    func refused() {
        let url = StorageValue<String>(key: "hubPendingUnregistrationURLTest", defaultValue: "")
        defer { url.remove() }
        let store = MemoryKeyStore()
        store.accepts = false
        let pending = HubPendingUnregistration(store: store, hubURL: url)
        #expect(!pending.keep(key: "lfh_old", hubURL: "https://hub.example.com"))
        #expect(pending.current == nil)
    }

    @Test("the removal is done once the hub removes the device or no longer knows its key")
    func done() {
        #expect(HubPendingUnregistration.isDone(200))
        #expect(HubPendingUnregistration.isDone(204))
        #expect(HubPendingUnregistration.isDone(401))
        #expect(!HubPendingUnregistration.isDone(0))
        #expect(!HubPendingUnregistration.isDone(500))
        #expect(!HubPendingUnregistration.isDone(503))
        #expect(!HubPendingUnregistration.isDone(429))
    }
}

struct HubNotificationServiceTests {
    @Test("a hub push to a phone that is not connected is delivered quietly")
    func notConnected() {
        #expect(HubAppGroup.delivery(hubURL: nil, systemAlarm: true) == .quiet)
        #expect(HubAppGroup.delivery(hubURL: "", systemAlarm: true) == .quiet)
        #expect(HubAppGroup.delivery(hubURL: nil, systemAlarm: false) == .quiet)
    }

    @Test("a connected phone rings the system alarm the hub asks for")
    func connected() {
        #expect(HubAppGroup.delivery(hubURL: "https://hub.example.com", systemAlarm: true) == .systemAlarm)
        #expect(HubAppGroup.delivery(hubURL: "https://hub.example.com", systemAlarm: false) == .notification)
    }
}

struct HubNotificationPermissionTests {
    @Test("only notifications that are allowed and show alerts let the hub deliver the alarms")
    func allows() {
        #expect(HubClient.notificationsAllow(.authorized, alertSetting: .enabled))
        #expect(!HubClient.notificationsAllow(.authorized, alertSetting: .disabled))
        #expect(!HubClient.notificationsAllow(.provisional, alertSetting: .enabled))
        #expect(!HubClient.notificationsAllow(.denied, alertSetting: .disabled))
        #expect(!HubClient.notificationsAllow(.notDetermined, alertSetting: .notSupported))
    }
}

struct HubAlarmTypeTests {
    @Test("the hub's API 1 checks every alarm type this app has")
    func parity() {
        #expect(HubClient.hubAlarmTypes[1] == Set(AlarmType.allCases))
        for type in AlarmType.allCases {
            #expect(HubClient.hubChecks(type, api: 1))
            #expect(HubClient.hubChecks(type, api: 3))
        }
    }

    @Test("without a known hub API the app checks every alarm itself")
    func unknownHub() {
        #expect(!HubClient.hubChecks(.low, api: nil))
        #expect(!HubClient.hubChecks(.low, api: 0))
        let alarms = [Alarm(type: .low), Alarm(type: .dbSize)]
        #expect(HubClient.alarmsCheckedHere(alarms, hubAPI: nil).map(\.id) == alarms.map(\.id))
        #expect(HubClient.alarmsCheckedHere(alarms, hubAPI: 1).isEmpty)
    }
}

struct HubInvitedRoleTests {
    @Test("joining with an invite makes a member, the setup token an admin")
    func joinRole() {
        #expect(HubClient.joinRole(withInvite: true) == .member)
        #expect(HubClient.joinRole(withInvite: false) == .admin)
    }

    @Test("a hub that reports no role leaves an invited phone a member; a reported role counts")
    func reportedRole() {
        #expect(HubClient.role(reported: nil, joinedWithInvite: true) == .member)
        #expect(HubClient.role(reported: nil, joinedWithInvite: false) == .admin)
        #expect(HubClient.role(reported: .admin, joinedWithInvite: true) == .admin)
        #expect(HubClient.role(reported: .member, joinedWithInvite: false) == .member)
    }

    @Test("a phone that joined with an invite never sends its own APN key")
    func noOwnKey() {
        #expect(HubClient.apnsKeyUse(keyId: "ABCDE12345", key: "p8", sentFingerprint: "", hubSharesKeys: true,
                                     ownKeyAllowed: false) == .shared)
        #expect(HubClient.apnsKeyUse(keyId: "ABCDE12345", key: "p8", sentFingerprint: "", hubSharesKeys: false,
                                     ownKeyAllowed: false) == .none)
    }
}

/// A key store in memory; `accepts` false makes it refuse every save.
final class MemoryKeyStore: HubKeyStore {
    var key: String?
    var accepts = true

    func load() -> String? { key }

    func save(_ key: String) -> Bool {
        guard accepts else { return false }
        self.key = key
        return true
    }

    func delete() { key = nil }
}

@Suite(.serialized)
struct HubDeviceKeyTests {
    private func legacy(_ value: String) -> StorageValue<String> {
        let stored = StorageValue<String>(key: "hubDeviceKeyTest", defaultValue: "")
        stored.value = value
        return stored
    }

    @Test("a key in the app's defaults moves to the store once")
    func migration() {
        let store = MemoryKeyStore()
        let old = legacy("lfh_old")
        defer { old.remove() }

        let key = HubDeviceKey(store: store, legacy: old)

        #expect(key.value == "lfh_old")
        #expect(store.key == "lfh_old")
        #expect(old.value.isEmpty)
        #expect(!old.exists)
    }

    @Test("a key the store does not take stays in the app's defaults and in use")
    func migrationRefused() {
        let store = MemoryKeyStore()
        store.accepts = false
        let old = legacy("lfh_old")
        defer { old.remove() }

        let key = HubDeviceKey(store: store, legacy: old)

        #expect(key.value == "lfh_old")
        #expect(old.value == "lfh_old")

        store.accepts = true
        key.reload()
        #expect(store.key == "lfh_old")
        #expect(!old.exists)
    }

    @Test("a stored key is read, replaced and cleared")
    func storedKey() throws {
        let store = MemoryKeyStore()
        store.key = "lfh_kept"
        let old = legacy("")
        defer { old.remove() }

        let key = HubDeviceKey(store: store, legacy: old)
        #expect(key.value == "lfh_kept")

        try key.set("lfh_new")
        #expect(key.value == "lfh_new")
        #expect(store.key == "lfh_new")

        store.accepts = false
        #expect(throws: HubClient.HubError.self) { try key.set("lfh_refused") }
        #expect(key.value == "lfh_new")

        key.clear()
        #expect(key.value.isEmpty)
        #expect(store.key == nil)
    }
}

struct HubJoinTests {
    private func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try HubClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test("the devices offered when joining decode without the push fields")
    func joinableDevices() throws {
        let list = try decode(HubClient.DeviceList.self, """
        {"devices":[{"id":"6f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a","name":"Old iPhone",
          "createdAt":"2026-01-01T10:00:00.123Z","lastSeenAt":null,"appVersion":null}]}
        """)
        #expect(list.devices.count == 1)
        #expect(list.devices[0].id == UUID(uuidString: "6F1C2A4E-0B7D-4C1E-9A55-2F3E4D5C6B7A"))
        #expect(list.devices[0].lastSeenAt == nil)
        #expect(list.devices[0].current == nil)
        #expect(try decode(HubClient.DeviceList.self, #"{"devices":[]}"#).devices.isEmpty)
    }

    @Test("the patient's devices decode with push state and the current marker")
    func devices() throws {
        let list = try decode(HubClient.DeviceList.self, """
        {"devices":[{"id":"6f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a","name":"iPhone","createdAt":"2026-01-01T10:00:00Z",
          "lastSeenAt":"2026-01-02T10:00:00Z","appVersion":"4.1.0","lastPushOkAt":"2026-01-02T09:59:00Z",
          "pushFailingSince":"2026-01-02T10:00:00Z","current":true}]}
        """)
        let device = try #require(list.devices.first)
        #expect(device.current == true)
        #expect(device.appVersion == "4.1.0")
        #expect(device.pushFailingSince != nil)
        #expect(device.lastSeenAt != nil)
    }

    @Test("a claim answer carries the device key")
    func claimResponse() throws {
        let claim = try decode(HubClient.ClaimResponse.self, """
        {"deviceId":"6f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a","deviceKey":"lfh_x","patientId":"7f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a"}
        """)
        #expect(claim.deviceKey == "lfh_x")
    }

    @Test("the hub's sources decode, and a hub without any has none")
    func sources() throws {
        let both = try decode(HubClient.Sources.self, """
        {"nightscoutUrl":"https://ns.example.com","token":"t","dexcom":{"username":"u","password":"p","server":"NON-US"}}
        """)
        #expect(!both.isEmpty)
        #expect(both.dexcom?.server == "NON-US")
        #expect(try decode(HubClient.Sources.self, #"{"nightscoutUrl":null,"token":null,"dexcom":null}"#).isEmpty)
        #expect(try !decode(HubClient.Sources.self, #"{"nightscoutUrl":null,"token":null,"dexcom":{"username":"u","password":"p","server":"US"}}"#).isEmpty)
    }

    @Test("every client setting is a stored value that takes its own JSON back")
    func clientSettingsRoundTrip() throws {
        let settings = HubClient.currentClientSettings()
        for setting in HubClient.clientSettings {
            guard let value = settings[setting.key] else { continue }
            let json = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            #expect(setting.assign(json: json), "\(setting.key)")
        }
        #expect(!HubClient.clientSettings[0].assign(json: Data("{\"not\":\"a unit\"}".utf8)))
    }

    @Test("only a local test hub may use plain http")
    func hubBase() throws {
        #expect(try HubClient.hubBase(" https://hub.example.com/ ") == "https://hub.example.com")
        #expect(try HubClient.hubBase("http://localhost:8080") == "http://localhost:8080")
        #expect(throws: HubClient.HubError.self) { try HubClient.hubBase("http://hub.example.com") }
    }
}

struct HubTelemetryTests {
    @Test("hub fields are sent only while connected, and never the address")
    func hubFields() {
        #expect(TelemetryClient.hubFields(connected: false, drivesAlarms: false, hub: nil).isEmpty)

        let hub = HubClient.Status.Hub(version: "0.2.0", api: 1, features: ["receipts", "devices"])
        let fields = TelemetryClient.hubFields(connected: true, drivesAlarms: true, hub: hub)
        #expect(fields["hubConfirmed"] as? Bool == true)
        #expect(fields["hubVersion"] as? String == "0.2.0")
        #expect(fields["hubApi"] as? Int == 1)
        #expect(Set(fields.keys) == ["hubConfirmed", "hubVersion", "hubApi"])

        let unanswered = TelemetryClient.hubFields(connected: true, drivesAlarms: false, hub: nil)
        #expect(Set(unanswered.keys) == ["hubConfirmed"])
    }
}

struct BGAnnouncementTests {
    private let swedish = Locale(identifier: "sv_SE")

    @Test("a small change is spoken as stable")
    func stable() {
        #expect(BGAnnouncement.text(current: 153, previous: 151, language: "sv", mmol: true, locale: swedish)
            == "Blodsockret är 8.5 och det är stabilt")
    }

    @Test("a rise and a fall are spoken with their size in the display unit")
    func change() {
        #expect(BGAnnouncement.text(current: 160, previous: 150, language: "en", mmol: false, locale: swedish)
            == "Glucose is 160 and it is up 10")
        #expect(BGAnnouncement.text(current: 140, previous: 158, language: "sv", mmol: true, locale: swedish)
            == "Blodsockret är 7.8 och det har minskat med 1.0")
    }

    @Test("an unknown language speaks English with the US voice")
    func fallback() {
        #expect(BGAnnouncement.text(current: 100, previous: 100, language: "xx", mmol: false, locale: swedish)
            == "Glucose is 100 and it is stable")
        #expect(BGAnnouncement.voiceLanguageCode(forAppLanguage: "xx") == "en-US")
    }
}

struct HubRoleTests {
    private func status(role: String?, apnsKeyShared: Bool? = nil, sourceRevision: Int? = nil) throws -> HubClient.Status {
        var device: [String: Any] = [
            "name": "Phone", "apnsConfigured": true,
            "liveActivity": ["registered": false, "pushToStartRegistered": false, "renewalFailed": false],
        ]
        if let role { device["role"] = role }
        if let apnsKeyShared { device["apnsKeyShared"] = apnsKeyShared }
        var patient: [String: Any] = ["name": "Patient"]
        if let sourceRevision { patient["sourceRevision"] = sourceRevision }
        let json: [String: Any] = ["device": device, "patient": patient,
                                   "live": ["connected": true, "staleAfterSeconds": 600]]
        return try HubClient.decoder.decode(HubClient.Status.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("roles decode, an unknown role counts as member, and a hub without roles sends none")
    func roles() throws {
        #expect(try status(role: "admin").device.role == .admin)
        #expect(try status(role: "member").device.role == .member)
        #expect(try status(role: "owner").device.role == .member)
        #expect(try status(role: nil).device.role == nil)
    }

    @Test("the device list, the join answer and the status carry the new fields")
    func fields() throws {
        let list = try HubClient.decoder.decode(HubClient.DeviceList.self, from: Data("""
        {"devices":[{"id":"6f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a","name":"Mum","role":"admin",
          "createdAt":"2026-01-01T10:00:00Z","lastSeenAt":null,"appVersion":null}]}
        """.utf8))
        #expect(list.devices.first?.role == .admin)

        let join = try JSONDecoder().decode(HubClient.ClaimResponse.self, from: Data("""
        {"deviceId":"6f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a","deviceKey":"lfh_x",
         "patientId":"7f1c2a4e-0b7d-4c1e-9a55-2f3e4d5c6b7a","role":"member"}
        """.utf8))
        #expect(join.role == .member)

        let shared = try status(role: "member", apnsKeyShared: true, sourceRevision: 4)
        #expect(shared.device.apnsKeyShared == true)
        #expect(shared.patient.sourceRevision == 4)
        #expect(try status(role: nil).patient.sourceRevision == nil)
    }
}

struct HubInviteTests {
    private let code = "AbCdEfGhIjKlMnOpQrStUvWxYz0"

    @Test("an invite link names the hub and the code")
    func parse() throws {
        let invite = try #require(HubClient.Invite(link: " https://hub.example.com/join#\(code)\n"))
        #expect(invite.hubURL == "https://hub.example.com")
        #expect(invite.code == code)
        #expect(invite.link == "https://hub.example.com/join#\(code)")
        #expect(HubClient.Invite(link: invite.link) == invite)
    }

    @Test("a hub under a path, with a port or a trailing slash is read too")
    func variants() {
        #expect(HubClient.Invite(link: "https://example.com/lfhub/join#\(code)")?.hubURL == "https://example.com/lfhub")
        #expect(HubClient.Invite(link: "https://hub.example.com:8443/join/#\(code)")?.hubURL == "https://hub.example.com:8443")
        #expect(HubClient.Invite(link: "https://hub.example.com/join?utm=x#\(code)")?.hubURL == "https://hub.example.com")
        #expect(HubClient.Invite(link: "http://localhost:8080/join#\(code)")?.hubURL == "http://localhost:8080")
    }

    @Test("anything else is not an invite")
    func rejected() {
        for link in [
            "http://hub.example.com/join#\(code)",
            "ftp://hub.example.com/join#\(code)",
            "https://user:pass@hub.example.com/join#\(code)",
            "https://hub.example.com/join",
            "https://hub.example.com/join#",
            "https://hub.example.com/joinx#\(code)",
            "https://hub.example.com/#\(code)",
            "https://hub.example.com/join#short",
            "https://hub.example.com/join#\(code)%20",
            "https://hub.example.com/join#\(code)!",
            "hub.example.com/join#\(code)",
            "not a link",
        ] {
            #expect(HubClient.Invite(link: link) == nil, "\(link)")
        }
    }
}

struct HubSourceRevisionTests {
    @Test("the hub's sources are taken when the hub counts revisions and this one is not applied")
    func needsSources() {
        #expect(!HubSourceSync.needsSources(hubRevision: nil, applied: -1))
        #expect(!HubSourceSync.needsSources(hubRevision: 3, applied: 3))
        #expect(HubSourceSync.needsSources(hubRevision: 4, applied: 3))
        #expect(HubSourceSync.needsSources(hubRevision: 0, applied: -1))
        #expect(HubSourceSync.needsSources(hubRevision: 2, applied: 3))
    }

    @Test("only the revision right after this app's own change counts as that change")
    func ownChange() {
        #expect(HubSourceSync.isOwnChange(revisionBefore: 3, revisionAfter: 4))
        #expect(!HubSourceSync.isOwnChange(revisionBefore: 3, revisionAfter: 5))
        #expect(!HubSourceSync.isOwnChange(revisionBefore: 3, revisionAfter: 3))
        #expect(!HubSourceSync.isOwnChange(revisionBefore: 3, revisionAfter: nil))
        #expect(!HubSourceSync.isOwnChange(revisionBefore: -1, revisionAfter: 0))
    }

    private func sources(_ json: String) throws -> HubClient.Sources {
        try JSONDecoder().decode(HubClient.Sources.self, from: Data(json.utf8))
    }

    @Test("a source the hub does not have leaves no old credentials behind")
    func noStaleCredentials() throws {
        let dexcomOnly = try LocalSources(sources(
            #"{"nightscoutUrl":null,"token":"old","dexcom":{"username":"u","password":"p","server":"NON-US"}}"#
        ), server: "US")
        #expect(dexcomOnly == LocalSources(dexcomUser: "u", dexcomPassword: "p", dexcomServer: "NON-US"))

        let nightscoutOnly = try LocalSources(sources(
            #"{"nightscoutUrl":"https://ns.example.com","token":"t","dexcom":null}"#
        ), server: "US")
        #expect(nightscoutOnly == LocalSources(nightscoutURL: "https://ns.example.com", token: "t", dexcomServer: "US"))
        #expect(!nightscoutOnly.hasDexcom)
    }

    @Test("the digest covers what the hub holds")
    func digest() {
        let base = LocalSources(nightscoutURL: "https://ns.example.com", token: "t",
                                dexcomUser: "u", dexcomPassword: "p", dexcomServer: "US")
        var changed = base
        changed.dexcomPassword = "q"
        #expect(base.digest != changed.digest)
        changed = base
        changed.token = "u"
        #expect(base.digest != changed.digest)

        // A token without an address and a server without a login are not at the hub.
        #expect(LocalSources(token: "t").digest == LocalSources().digest)
        #expect(LocalSources(dexcomServer: "NON-US").digest == LocalSources(dexcomServer: "US").digest)
    }
}

struct HubSharedApnKeyTests {
    @Test("an own key is sent only when it changed; without one a hub that shares keys is asked for an admin's")
    func keyUse() {
        let fingerprint = HubClient.keyFingerprint(keyId: "ABCDE12345", key: "p8")
        #expect(HubClient.apnsKeyUse(keyId: "ABCDE12345", key: "p8", sentFingerprint: "", hubSharesKeys: true)
            == .own(keyId: "ABCDE12345", sendKey: true))
        #expect(HubClient.apnsKeyUse(keyId: "ABCDE12345", key: "p8", sentFingerprint: fingerprint, hubSharesKeys: false)
            == .own(keyId: "ABCDE12345", sendKey: false))
        #expect(HubClient.apnsKeyUse(keyId: "", key: "", sentFingerprint: "", hubSharesKeys: true) == .shared)
        #expect(HubClient.apnsKeyUse(keyId: "ABCDE12345", key: "", sentFingerprint: "", hubSharesKeys: true) == .shared)
        #expect(HubClient.apnsKeyUse(keyId: "", key: "", sentFingerprint: "", hubSharesKeys: false) == .none)
    }

    private func status(apnsKeyShared: Bool, apnsConfigured: Bool = true) throws -> HubClient.Status {
        let json: [String: Any] = [
            "hub": ["version": "1.0.0", "api": 1, "features": ["receipts", "sharedApnsKey"]],
            "device": [
                "name": "Phone", "role": "member", "apnsConfigured": apnsConfigured, "apnsKeyShared": apnsKeyShared,
                "lastPushOkAt": "2026-01-01T11:59:00Z",
                "liveActivity": ["registered": true, "pushToStartRegistered": true, "renewalFailed": false],
            ],
            "patient": ["name": "Patient", "nightscoutHost": "ns.example.com", "followed": true, "hasData": true],
            "live": ["connected": true, "staleAfterSeconds": 600],
        ]
        return try HubClient.decoder.decode(HubClient.Status.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private let now = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!

    private func item(_ id: HubChecklist.Item.ID, _ status: HubClient.Status, _ facts: HubChecklist.Facts)
        -> HubChecklist.Item?
    {
        HubChecklist.items(status: status, error: nil, facts: facts, now: now).first { $0.id == id }
    }

    @Test("a key an admin shares counts as this phone's APN key")
    func sharedKeyIsReady() throws {
        var facts = HubChecklist.Facts()
        facts.ownApnKey = false
        facts.isAdmin = false
        facts.hubSharesKeys = true
        let apnKey = try #require(try item(.apnKey, status(apnsKeyShared: true), facts))
        #expect(apnKey.isReady)
        #expect(apnKey.title == "APN key shared by an admin")
        #expect(try item(.push, status(apnsKeyShared: true), facts)?.isReady == true)
    }

    @Test("without a key of its own or a shared one, the phone is sent to the APN settings")
    func missingKey() throws {
        var facts = HubChecklist.Facts()
        facts.ownApnKey = false
        facts.isAdmin = false
        facts.hubSharesKeys = true
        let apnKey = try #require(try item(.apnKey, status(apnsKeyShared: false, apnsConfigured: false), facts))
        #expect(!apnKey.isReady)
        #expect(apnKey.fix == .goToAPN)
        #expect(try item(.push, status(apnsKeyShared: false, apnsConfigured: false), facts) == nil)
    }
}

struct HubChecklistTests {
    private func status(nightscoutHost: String? = "ns.example.com", followed: Bool = true,
                        hasData: Bool = true) throws -> HubClient.Status
    {
        var patient: [String: Any] = ["name": "Patient", "followed": followed, "hasData": hasData]
        if let nightscoutHost { patient["nightscoutHost"] = nightscoutHost }
        let json: [String: Any] = [
            "hub": ["version": "1.0.0", "api": 1, "features": ["receipts"]],
            "device": [
                "name": "Phone", "apnsConfigured": true, "lastPushOkAt": "2026-01-01T11:59:00Z",
                "liveActivity": ["registered": true, "pushToStartRegistered": true, "renewalFailed": false],
            ],
            "patient": patient,
            "live": ["connected": true, "staleAfterSeconds": 600],
        ]
        return try HubClient.decoder.decode(HubClient.Status.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private let now = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!

    private func items(_ status: HubClient.Status?, error: String? = nil,
                       _ change: (inout HubChecklist.Facts) -> Void = { _ in }) -> [HubChecklist.Item]
    {
        var facts = HubChecklist.Facts()
        facts.notifications = .allowed
        change(&facts)
        return HubChecklist.items(status: status, error: error, facts: facts, now: now)
    }

    @Test("everything in place is all ready")
    func ready() throws {
        let all = try items(status())
        #expect(all.allSatisfy { $0.isReady })
        #expect(all.map(\.id) == [.hub, .mode, .notifications, .alarmKit, .liveActivity, .apnKey, .push, .source, .confirmed])
    }

    @Test("a hub that does not answer shows only that, with Try Again; none before the first answer")
    func noAnswer() {
        #expect(items(nil, error: "offline").map(\.fix) == [.retry])
        #expect(items(nil).isEmpty)
    }

    @Test("each missing permission comes with its fix")
    func permissions() throws {
        let missing = try items(status()) {
            $0.notifications = .denied
            $0.alarmKit = .notAsked
            $0.liveActivityOn = false
            $0.hubMode = true
        }
        #expect(missing.first { $0.id == .notifications }?.fix == .openNotificationSettings)
        #expect(missing.first { $0.id == .alarmKit }?.fix == .askAlarmKit)
        #expect(missing.first { $0.id == .liveActivity }?.fix == .turnOnLiveActivity)
        #expect(try items(status()) { $0.alarmKit = .denied }.first { $0.id == .alarmKit }?.fix == .openSettings)
    }

    @Test("a data source problem is the admin's to fix; a member asks an admin")
    func dataSource() throws {
        #expect(try items(status(nightscoutHost: nil)).first { $0.id == .source }?.fix == .dataSource(dexcom: false))
        #expect(try items(status(followed: false)) { $0.isAdmin = false }.first { $0.id == .source }?.fix == .askAdmin)
        #expect(try items(status()) { $0.sourcesDiffer = true }.first { $0.id == .source }?.fix == .sendSources)
        #expect(try items(status()) { $0.sourcesDiffer = true; $0.isAdmin = false }.first { $0.id == .source }?.isReady == true)
    }

    @Test("outside Hub mode the hub's own items are left out and Hub mode is offered")
    func notHubMode() throws {
        let list = try items(status()) { $0.hubMode = false }
        #expect(list.first { $0.id == .mode }?.fix == .useHubMode)
        #expect(!list.contains { $0.id == .liveActivity || $0.id == .confirmed })
    }

    @Test("notifications that are off show on their own item, not again on the confirmation")
    func notificationsOff() throws {
        let list = try items(status()) {
            $0.notifications = .denied
            $0.drivesAlarms = false
            $0.hubProblems = [HubClient.Problem.notificationsOff]
        }
        #expect(list.first { $0.id == .notifications }?.problem == HubClient.Problem.notificationsOff)
        #expect(list.first { $0.id == .confirmed }?.problem != HubClient.Problem.notificationsOff)
        #expect(list.first { $0.id == .confirmed }?.isReady == false)
    }

    @Test("a phone that joined with an invite asks an admin for an APN key")
    func invitedPhoneApnKey() throws {
        let item = try items(status()) {
            $0.ownApnKey = false
            $0.ownKeyAllowed = false
            $0.isAdmin = false
            $0.hubSharesKeys = true
        }.first { $0.id == .apnKey }
        #expect(item?.fix == .askAdmin)
    }

    @Test("the hub's reasons not covered by another item show on the confirmation")
    func confirmation() throws {
        let list = try items(status()) {
            $0.drivesAlarms = false
            $0.hubProblems = [HubClient.Problem.alarmsOff, HubClient.Problem.noPushYet]
        }
        #expect(list.first { $0.id == .confirmed }?.problem == HubClient.Problem.alarmsOff)
    }
}

struct HubRemoteSecretTests {
    /// Every stored value of Remote: the commands' secrets, the remote APN key and the
    /// AID app's push identity.
    private var remoteValues: [String] {
        let storage = Storage.shared
        return [storage.remoteType.key, storage.deviceToken.key, storage.expirationDate.key, storage.sharedSecret.key,
                storage.productionEnvironment.key, storage.remoteApnsKey.key, storage.teamId.key,
                storage.remoteKeyId.key, storage.bundleId.key, storage.user.key, storage.loopAPNSQrCodeURL.key,
                storage.maxBolus.key, storage.maxCarbs.key, storage.maxProtein.key, storage.maxFat.key]
    }

    @Test("no Remote setting is a client setting, so none is sent to the hub or taken from it")
    func clientSettings() {
        #expect(Set(HubClient.clientSettingKeys).isDisjoint(with: remoteValues))
        #expect(Set(HubClient.currentClientSettings().keys).isDisjoint(with: remoteValues))
    }

    @Test("client settings from the hub cannot set a Remote value")
    @MainActor func adoption() {
        let storage = Storage.shared
        let saved = storage.sharedSecret.value
        HubClient.applyClientSettings(Dictionary(uniqueKeysWithValues: remoteValues.map { ($0, "from the hub") }))
        #expect(storage.sharedSecret.value == saved)
    }
}

/// Answers GET /v1/patient/source on `host` with the hub's sources, and 404 otherwise.
final class HubSourcesProtocol: URLProtocol {
    static let host = "sources.lfhub-tests.invalid"
    static let sources = #"{"nightscoutUrl":"https://ns.lfhub-tests.invalid","token":"hub-token","dexcom":null}"#

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let found = request.url?.path == "/v1/patient/source"
        let response = HTTPURLResponse(url: request.url!, statusCode: found ? 200 : 404, httpVersion: nil,
                                       headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((found ? Self.sources : "{}").utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension HubForgottenTests {
    @Test("any call the hub answers 401 leaves the hub at once, falls back to the app's alarms and tells the user")
    func unauthorizedCall() async throws {
        let storage = Storage.shared
        let client = HubClient.shared
        let saved = (storage.hubURL.value, client.deviceKey.store, storage.backgroundRefreshType.value,
                     client.removedFromHub.value)
        client.deviceKey.store = MemoryKeyStore()
        URLProtocol.registerClass(HubUnauthorizedProtocol.self)
        defer {
            URLProtocol.unregisterClass(HubUnauthorizedProtocol.self)
            storage.hubURL.value = saved.0
            client.deviceKey.store = saved.1
            client.deviceKey.reload()
            storage.backgroundRefreshType.value = saved.2
            client.removedFromHub.value = saved.3
        }
        for call in ["health check", "bundle"] {
            try await MainActor.run {
                storage.hubURL.value = "https://\(HubUnauthorizedProtocol.host)"
                try client.deviceKey.set("lfh_replaced")
                storage.backgroundRefreshType.value = .hub
                client.removedFromHub.value = false
            }

            if call == "bundle" {
                _ = try? await client.bundle(since: 0, wait: 0)
            } else {
                let (health, cause) = await client.healthCheck()
                // Not a hub outage: the watchdog does not count it.
                #expect(health == .unknown)
                #expect(cause == nil)
            }

            await MainActor.run {
                #expect(!client.isConnected, "\(call)")
                #expect(client.removedFromHub.value, "\(call)")
                #expect(storage.backgroundRefreshType.value == .silentTune, "\(call)")
            }
        }
        await Self.stopBackgroundWork()
    }

    @Test("Undo puts the hub's data source back in this app's settings")
    @MainActor func undoSourceChange() async throws {
        let storage = Storage.shared
        let client = HubClient.shared
        let saved = (storage.hubURL.value, client.deviceKey.store, storage.url.value, storage.token.value,
                     storage.shareUserName.value, storage.sharePassword.value)
        client.deviceKey.store = MemoryKeyStore()
        URLProtocol.registerClass(HubSourcesProtocol.self)
        defer {
            URLProtocol.unregisterClass(HubSourcesProtocol.self)
            storage.hubURL.value = saved.0
            client.deviceKey.store = saved.1
            client.deviceKey.reload()
            storage.url.value = saved.2
            storage.token.value = saved.3
            storage.shareUserName.value = saved.4
            storage.sharePassword.value = saved.5
            HubSourceSync.shared.forget()
        }
        storage.hubURL.value = "https://\(HubSourcesProtocol.host)"
        try client.deviceKey.set("lfh_admin")
        storage.url.value = "https://wrong.example.com"
        storage.token.value = "wrong"
        storage.shareUserName.value = ""
        storage.sharePassword.value = ""

        await HubSourceSync.shared.undo()

        #expect(storage.url.value == "https://ns.lfhub-tests.invalid")
        #expect(storage.token.value == "hub-token")
        #expect(!HubSourceSync.shared.differsFromHub)
        #expect(HubSourceSync.shared.state == .idle)
        await Self.stopBackgroundWork()
    }
}

struct HubPushFailureTests {
    private let now = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!

    private func status(lastPushStatus: String?, pushFailingSince: String? = "2026-01-01T11:59:00Z",
                        lastPushOkAt: String? = "2026-01-01T11:58:00Z", alarmCount: Int? = nil) throws -> HubClient.Status
    {
        var device: [String: Any] = [
            "name": "Phone", "apnsConfigured": true, "apnsKeyShared": true, "alarmsReceived": true, "settings": ["alarms": true],
            "liveActivity": ["registered": true, "pushToStartRegistered": true, "renewalFailed": false],
        ]
        if let lastPushStatus { device["lastPushStatus"] = lastPushStatus }
        if let pushFailingSince { device["pushFailingSince"] = pushFailingSince }
        if let lastPushOkAt { device["lastPushOkAt"] = lastPushOkAt }
        if let alarmCount { device["alarmCount"] = alarmCount }
        let json: [String: Any] = [
            "hub": ["version": "0.2.0", "api": 1, "features": ["receipts"]],
            "device": device,
            "patient": ["name": "Patient", "nightscoutHost": "ns.example.com", "followed": true, "hasData": true],
            "live": ["connected": true, "staleAfterSeconds": 600],
        ]
        return try HubClient.decoder.decode(HubClient.Status.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func problems(_ status: HubClient.Status, exportedAlarms: Int? = nil, alarmsPending: Bool = false) -> [String] {
        HubClient.confirmationProblems(status, alarmsPending: alarmsPending, alarmKitAuthorized: true,
                                       notificationsAllowed: true, now: now, exportedAlarms: exportedAlarms)
    }

    @Test("Apple rejecting the APN key or the phone's registration makes the app alarm itself at once")
    func rejectedAtOnce() throws {
        let key = try status(lastPushStatus: "403 InvalidProviderToken")
        #expect(HubClient.unhealthiness(of: key, now: now) == .keyRejected)
        #expect(HubClient.health(of: key, now: now) == .unhealthy)
        #expect(problems(key) == [HubClient.Problem.apnKeyRejected])

        let neverReached = try status(lastPushStatus: "403 InvalidProviderToken", lastPushOkAt: nil)
        #expect(HubClient.unhealthiness(of: neverReached, now: now) == .keyRejected)

        let registration = try status(lastPushStatus: "400 BadDeviceToken")
        #expect(HubClient.unhealthiness(of: registration, now: now) == .registrationRejected)
        #expect(problems(registration) == [HubClient.Problem.pushFailing])
        #expect(try HubClient.unhealthiness(of: status(lastPushStatus: "410 Unregistered"), now: now) == .registrationRejected)
    }

    @Test("a failure that may pass is tolerated for a while, and an accepted push clears it")
    func passingFailure() throws {
        #expect(try HubClient.unhealthiness(of: status(lastPushStatus: "503 ServiceUnavailable"), now: now) == nil)
        #expect(try HubClient.unhealthiness(of: status(lastPushStatus: "503 ServiceUnavailable",
                                                       pushFailingSince: "2026-01-01T11:45:00Z"), now: now) == .pushFailing)
        #expect(try HubClient.unhealthiness(of: status(lastPushStatus: "403 InvalidProviderToken",
                                                       pushFailingSince: nil), now: now) == nil)
    }

    @Test("the Ready list names the rejected key and sends the fix where the key was added")
    func checklist() throws {
        func push(_ status: HubClient.Status, ownApnKey: Bool) -> HubChecklist.Item? {
            var facts = HubChecklist.Facts()
            facts.notifications = .allowed
            facts.ownApnKey = ownApnKey
            facts.hubSharesKeys = true
            return HubChecklist.items(status: status, error: nil, facts: facts, now: now).first { $0.id == .push }
        }
        let key = try status(lastPushStatus: "403 InvalidProviderToken")
        #expect(push(key, ownApnKey: true)?.fix == .goToAPN)
        #expect(push(key, ownApnKey: true)?.problem?.hasPrefix(HubClient.Problem.apnKeyRejected) == true)
        #expect(push(key, ownApnKey: false)?.fix == .askAdmin)
        #expect(try push(status(lastPushStatus: "400 BadDeviceToken"), ownApnKey: true)?.fix == .registerAgain)
        #expect(try push(status(lastPushStatus: nil, pushFailingSince: nil), ownApnKey: true)?.isReady == true)
    }

    @Test("the watchdog's alert names the real cause")
    func watchdogAlert() {
        #expect(HubWatchdog.alert(for: .noAnswer, minutes: 20).title == "⚠️ LF Hub not responding")
        #expect(HubWatchdog.alert(for: nil, minutes: 20).title == "⚠️ LF Hub not responding")
        #expect(HubWatchdog.alert(for: .keyRejected, minutes: 20).title.contains("APN key"))
        #expect(HubWatchdog.alert(for: .pushFailing, minutes: 20).title == "⚠️ LF Hub can't reach this phone")
        #expect(HubWatchdog.alert(for: .registrationRejected, minutes: 20).body.contains("20 minutes"))
    }

    @Test("fewer alarms at the hub than this app exported leaves the alarms unconfirmed")
    func skippedAlarms() throws {
        let fine = try status(lastPushStatus: nil, pushFailingSince: nil, alarmCount: 3)
        #expect(problems(fine, exportedAlarms: 3).isEmpty)
        #expect(problems(fine, exportedAlarms: 2).isEmpty)
        #expect(problems(fine, exportedAlarms: 4) == [HubClient.Problem.alarmsSkipped])
        #expect(!HubClient.confirms(fine, hubMode: true, alarmsPending: false, alarmKitAuthorized: true,
                                    notificationsAllowed: true, now: now, exportedAlarms: 4))
        // An upload on its way is reported as that, and a hub without the count is not judged.
        #expect(problems(fine, exportedAlarms: 4, alarmsPending: true) == [HubClient.Problem.alarmsNotReceived])
        #expect(try problems(status(lastPushStatus: nil, pushFailingSince: nil), exportedAlarms: 4).isEmpty)
        #expect(HubClient.alarmCountForHub([], hubAPI: 1) == 0)
    }
}

struct HubClientBehaviourTests {
    private enum Step: Equatable { case upload, handled }

    private final class Recorder: @unchecked Sendable {
        var steps: [Step] = []
    }

    @Test("a snooze reaches the hub before the alarm is reported handled")
    func handledAfterUpload() async throws {
        let recorder = Recorder()
        try await HubClient.reportHandled(upload: { recorder.steps.append(.upload) },
                                          handled: { recorder.steps.append(.handled) })
        #expect(recorder.steps == [.upload, .handled])

        // An upload the hub refuses for good does not hold back the report.
        let refused = Recorder()
        try await HubClient.reportHandled(upload: { throw HubClient.HubError.http(400, "bad") },
                                          handled: { refused.steps.append(.handled) })
        #expect(refused.steps == [.handled])

        // One that may pass fails the step, so it is retried before the report.
        let offline = Recorder()
        await #expect(throws: URLError.self) {
            try await HubClient.reportHandled(upload: { throw URLError(.timedOut) },
                                              handled: { offline.steps.append(.handled) })
        }
        #expect(offline.steps.isEmpty)
    }

    @Test("errors read in plain words, never as the hub's raw answer")
    func errorMessages() {
        func message(_ code: Int, _ detail: String) -> String {
            HubClient.userMessage(for: HubClient.HubError.http(code, detail))
        }
        #expect(message(403, "unknown, used or expired invite") == HubClient.HubError.inviteNotValid.errorDescription)
        #expect(message(409, "the patient must keep an admin device").contains("at least one admin"))
        #expect(message(502, "APNs: 403 InvalidProviderToken")
            .hasPrefix("Apple rejected the push: it does not accept the APN key"))
        #expect(message(502, "APNs: 500 InternalServerError") == "Apple rejected the push: 500 InternalServerError")
        #expect(message(429, "too many claims") == HubClient.HubError.tooManyTries.errorDescription)
        #expect(message(403, "only an admin device can invite") == "Only an admin can do this.")
        #expect(message(403, "an invite cannot take over an admin device").contains("cannot replace an admin's phone"))
        #expect(message(503, "the patient is not followed yet").hasPrefix("LF Hub had a problem"))
        for code in [400, 401, 403, 404, 409, 429, 500, 502, 503] {
            #expect(!message(code, "detail").contains("Hub responded"))
        }
        #expect(HubClient.userMessage(for: URLError(.notConnectedToInternet)).contains("offline"))
    }

    @Test("an invite is looked up when pasted or submitted, never while it is typed")
    func inviteLookup() {
        let link = "https://hub.example.com/join#abcdefghijklmnopqrstuvwxyz012345"
        #expect(HubClient.Invite.pasted(from: "", to: link) == HubClient.Invite(link: link))
        #expect(HubClient.Invite.pasted(from: String(link.dropLast()), to: link) == nil)
        #expect(HubClient.Invite.pasted(from: "", to: "https://hub.example.com/join#abc") == nil)
        #expect(HubClient.Invite.pasted(from: "https://hub", to: "https://hub.example.com") == nil)
    }

    @Test("the same upload right after the last is skipped, whatever the order of its keys")
    func repeatedUploads() throws {
        let uploads = RecentUploads()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try #require(RecentUploads.digest(body: ["a": 1, "b": [true]], rawBody: nil))
        let reordered = try #require(RecentUploads.digest(body: nil, rawBody: Data(#"{"b":[true],"a":1}"#.utf8)))
        let other = try #require(RecentUploads.digest(body: ["a": 2, "b": [true]], rawBody: nil))
        #expect(first == reordered)

        #expect(!uploads.isRepeat("/v1/device/alarms", first, now: now))
        uploads.record("/v1/device/alarms", first, now: now)
        #expect(uploads.isRepeat("/v1/device/alarms", reordered, now: now.addingTimeInterval(1)))
        #expect(!uploads.isRepeat("/v1/device/alarms", other, now: now.addingTimeInterval(1)))
        #expect(!uploads.isRepeat("/v1/device/settings", first, now: now.addingTimeInterval(1)))
        #expect(!uploads.isRepeat("/v1/device/alarms", first, now: now.addingTimeInterval(RecentUploads.window)))
        uploads.forget()
        #expect(!uploads.isRepeat("/v1/device/alarms", first, now: now.addingTimeInterval(1)))
    }

    @Test("replacing a phone used in the last 15 minutes asks first")
    func recentUse() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func device(lastSeen: TimeInterval?) throws -> HubClient.Device {
            var json: [String: Any] = ["id": UUID().uuidString, "name": "Old iPhone", "createdAt": "2026-01-01T10:00:00Z"]
            if let lastSeen {
                json["lastSeenAt"] = ISO8601DateFormatter().string(from: now.addingTimeInterval(-lastSeen))
            }
            return try HubClient.decoder.decode(HubClient.Device.self, from: JSONSerialization.data(withJSONObject: json))
        }
        #expect(try HubClient.recentUseWarning(device(lastSeen: 120), now: now)
            == "Old iPhone was used 2 minutes ago. Replace it anyway?")
        #expect(try HubClient.recentUseWarning(device(lastSeen: 10), now: now)
            == "Old iPhone was used just now. Replace it anyway?")
        #expect(try HubClient.recentUseWarning(device(lastSeen: HubClient.recentUse), now: now) == nil)
        #expect(try HubClient.recentUseWarning(device(lastSeen: nil), now: now) == nil)
    }

    @Test("the devices offered when joining carry the patient's name when the hub sends it")
    func joinPatientName() throws {
        let named = #"{"patientName":"Nils","devices":[]}"#
        #expect(try HubClient.decoder.decode(HubClient.DeviceList.self, from: Data(named.utf8)).patientName == "Nils")
        #expect(try HubClient.decoder.decode(HubClient.DeviceList.self, from: Data(#"{"devices":[]}"#.utf8)).patientName == nil)
    }

    @Test("an admin that joined with an invite sends a data source change only when the user confirmed it")
    func confirmedSourceChange() {
        #expect(HubSourceSync.sendsChange(isAdmin: true, joinedWithInvite: false, confirmed: false))
        #expect(!HubSourceSync.sendsChange(isAdmin: true, joinedWithInvite: true, confirmed: false))
        #expect(HubSourceSync.sendsChange(isAdmin: true, joinedWithInvite: true, confirmed: true))
        #expect(!HubSourceSync.sendsChange(isAdmin: false, joinedWithInvite: true, confirmed: true))
    }

    @Test("times within a minute of now read as just now")
    func relativeTimes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(HubSettingsView.relative(now.addingTimeInterval(-5), now: now) == "just now")
        #expect(HubSettingsView.relative(now, now: now) == "just now")
        #expect(HubSettingsView.relative(now.addingTimeInterval(-600), now: now) != "just now")
    }

    @Test("an alarm whose snooze is 0 is acknowledged, as the app's own action for it reads")
    func acknowledgeCategory() {
        #expect(HubAppGroup.acknowledgeCategory == "lfhub-ack")
    }
}
