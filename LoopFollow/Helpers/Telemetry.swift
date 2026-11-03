// LoopFollow
// Telemetry.swift

import CryptoKit
import Foundation
import SwiftUI
import UIKit

// MARK: - TelemetrySendGate

/// Serializes send decisions across the launch, foreground and scheduler
/// triggers. Actors are reentrant, so `isSending` stays set while the
/// operation is suspended on network work.
actor TelemetrySendGate {
    private var isSending = false

    func runIfEligible(
        now: Date,
        lastSentAt: Date?,
        lastAttemptAt: Date?,
        minimumInterval: TimeInterval,
        retryInterval: TimeInterval,
        force: Bool = false,
        operation: () async -> Bool,
        onAttempt: () async -> Void = {},
        onSuccess: () async -> Void = {}
    ) async -> Bool {
        guard !isSending else { return false }
        guard force || Self.isOverdue(now: now, lastSentAt: lastSentAt, minimumInterval: minimumInterval) else {
            return false
        }
        guard Self.isOverdue(now: now, lastSentAt: lastAttemptAt, minimumInterval: retryInterval) else {
            return false
        }

        isSending = true
        defer { isSending = false }
        await onAttempt()
        let succeeded = await operation()
        if succeeded {
            await onSuccess()
        }
        return succeeded
    }

    nonisolated static func isOverdue(now: Date, lastSentAt: Date?, minimumInterval: TimeInterval) -> Bool {
        guard let lastSentAt else { return true }
        return now.timeIntervalSince(lastSentAt) >= minimumInterval
    }
}

// MARK: - TelemetryClient

/// Opt-out anonymous usage check-in. Sends the payload from `buildPayload()`
/// at most once every 24 hours, plus once after a new build is installed.
/// Installs that turned sharing off send only an empty daily `/anonymous` GET
/// carrying the app version, build, install identifier, trigger reason and
/// prior failure category, so active installs per version can be counted.
final class TelemetryClient {
    static let shared = TelemetryClient()

    enum SendReason: String {
        case background
        case buildChange = "build_change"
        case coldLaunch = "cold_launch"
        case foreground
        case optIn = "opt_in"
        case timer
    }

    private static let productionBaseURL = URL(string: "https://lf.bjorkert.se/api/telemetry/")!
    private static let salt = "lf-telemetry"
    private static let weeklyInterval: TimeInterval = 7 * 24 * 60 * 60
    private static let dailyInterval: TimeInterval = 24 * 60 * 60
    private static let retryInterval: TimeInterval = 60 * 60

    /// Static write token, committed in source. The LoopFollow repo is public,
    /// so this string is public too. The backend treats it as a "front door
    /// sign" rather than a secret: TLS, an NGINX rate limit (10 req/min/IP),
    /// strict validation, and insert-only storage bound any abuse to
    /// harmless row inserts.
    private static let writeToken = "RsEDJ8RoOs7HHZ_XGOdI1sY3Yuv6iPnRRk7tg-NlCAg"

    private let sendGate = TelemetrySendGate()
    private var foregroundObserver: NSObjectProtocol?

    private init() {}

    /// Debug builds honor `LF_TELEMETRY_BASE_URL` from the launch environment,
    /// which points simulator runs at a local server.
    private static var baseURL: URL {
        #if DEBUG
            if let override = ProcessInfo.processInfo.environment["LF_TELEMETRY_BASE_URL"],
               let url = URL(string: override.hasSuffix("/") ? override : override + "/")
            {
                return url
            }
        #endif
        return productionBaseURL
    }

    // MARK: - Lifecycle

    /// Called once per process from AppDelegate after storage is readable.
    /// Records the cold launch, sends immediately when the build changed since
    /// the last successful full send, then runs the daily overdue check and
    /// arms the scheduler. Foreground transitions repeat the overdue check.
    func start() {
        _ = installId()
        recordColdLaunch()

        if foregroundObserver == nil {
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.checkAndReschedule(reason: .foreground)
            }
        }

        Task.detached {
            await self.sendIfOverdue(reason: .coldLaunch)
            await MainActor.run { self.scheduleRecurring() }
        }
    }

    /// Called when the user turns sharing back on in Settings, so the first
    /// full payload arrives at once rather than after the next daily check.
    func sharingEnabled() {
        Task.detached {
            await self.sendNow(reason: .optIn)
            await MainActor.run { self.scheduleRecurring() }
        }
    }

    // MARK: - Cold launches

    /// Records a cold launch in a sliding 7-day window of timestamps. The count
    /// of entries in the window is sent as `coldLaunches7d` in each ping,
    /// giving a "how often is iOS recycling or killing this process" signal
    /// that's directly comparable across pings regardless of the cadence
    /// between them.
    func recordColdLaunch(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.weeklyInterval)
        var recent = Storage.shared.telemetryColdLaunchTimes.value
        recent.removeAll { $0 < cutoff }
        recent.append(now)
        Storage.shared.telemetryColdLaunchTimes.value = recent
    }

    // MARK: - Identity

    /// Stable per-install UUID, generated on first use. IDFV resets when every
    /// app from this developer is removed at once; this survives that and is
    /// wiped only by deleting this LoopFollow instance.
    func installId() -> String {
        let storage = Storage.shared
        if !storage.telemetryInstallId.value.isEmpty {
            return storage.telemetryInstallId.value
        }
        let new = UUID().uuidString
        storage.telemetryInstallId.value = new
        return new
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private static var commitSha: String {
        BuildDetails.default.commitSha ?? ""
    }

    private static var buildDate: String? {
        guard let date = BuildDetails.default.buildDateString, date.count >= 10 else { return nil }
        return String(date.prefix(10))
    }

    /// Version, build date and commit: the fields the server keys a build on,
    /// so every build it stores as new is also announced as new.
    private static var buildIdentity: String {
        "\(appVersion)|\(buildDate ?? "")|\(commitSha)"
    }

    /// True until a send of either kind succeeds on the running build.
    func buildChangedSinceLastSend() -> Bool {
        Storage.shared.telemetryLastSentBuild.value != Self.buildIdentity
    }

    // MARK: - Cadence

    /// Arms the scheduler for the next moment a send can be due: at once for an
    /// unreported build, otherwise 24h after the last successful send of the
    /// active kind, and never sooner than an hour after the last attempt. Each
    /// tick runs the overdue check and re-arms.
    func scheduleRecurring() {
        let storage = Storage.shared
        let lastSent = storage.telemetryEnabled.value
            ? storage.telemetryLastSentAt.value
            : storage.telemetryAnonymousLastSentAt.value
        let now = Date()

        var nextRun = buildChangedSinceLastSend()
            ? now
            : lastSent.map { $0.addingTimeInterval(Self.dailyInterval) } ?? now
        if let lastAttempt = storage.telemetryLastAttemptAt.value {
            nextRun = max(nextRun, lastAttempt.addingTimeInterval(Self.retryInterval))
        }
        nextRun = max(nextRun, now.addingTimeInterval(60))

        TaskScheduler.shared.scheduleTask(id: .telemetry, nextRun: nextRun) { [weak self] in
            let reason: SendReason = UIApplication.shared.applicationState == .background ? .background : .timer
            self?.checkAndReschedule(reason: reason)
        }
    }

    /// A background tick runs under its own UIKit background task, so iOS
    /// lets the request finish before suspending the app.
    private func checkAndReschedule(reason: SendReason) {
        let backgroundTask = BackgroundTask()
        if reason == .background {
            backgroundTask.begin(name: "Telemetry Check-In")
        }
        Task.detached {
            await self.sendIfOverdue(reason: reason)
            await MainActor.run {
                self.scheduleRecurring()
                backgroundTask.end()
            }
        }
    }

    /// One UIKit background task, ended exactly once by whichever comes
    /// first: the work finishing or the expiration handler. Main thread only.
    private final class BackgroundTask {
        private var id = UIBackgroundTaskIdentifier.invalid

        func begin(name: String) {
            id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
                self?.end()
            }
        }

        func end() {
            guard id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(id)
            id = .invalid
        }
    }

    /// Entry point shared by every trigger. Sends the full payload when
    /// sharing is on and the anonymous heartbeat when it is off: at once when
    /// the running build has not been reported yet, otherwise once the daily
    /// interval has passed. Storage is read and written on the main actor;
    /// only the request runs off it.
    @discardableResult func sendIfOverdue(reason: SendReason, now: Date = Date()) async -> Bool {
        let (sharing, lastSentAt, lastAttemptAt, buildChanged) = await MainActor.run {
            let storage = Storage.shared
            let sharing = storage.telemetryEnabled.value
            return (
                sharing,
                sharing ? storage.telemetryLastSentAt.value : storage.telemetryAnonymousLastSentAt.value,
                storage.telemetryLastAttemptAt.value,
                self.buildChangedSinceLastSend()
            )
        }
        let sendReason: SendReason = buildChanged ? .buildChange : reason

        return await sendGate.runIfEligible(
            now: now,
            lastSentAt: lastSentAt,
            lastAttemptAt: lastAttemptAt,
            minimumInterval: Self.dailyInterval,
            retryInterval: Self.retryInterval,
            force: buildChanged,
            operation: {
                sharing ? await self.send(reason: sendReason) : await self.sendAnonymous(reason: sendReason)
            },
            onAttempt: { await MainActor.run { Storage.shared.telemetryLastAttemptAt.value = now } },
            onSuccess: {
                await MainActor.run {
                    if sharing {
                        self.recordSuccessfulSend()
                    } else {
                        self.recordSuccessfulAnonymousSend()
                    }
                }
            }
        )
    }

    /// Full send regardless of the daily window, for a build change or a
    /// fresh opt-in. Still subject to the one-hour retry delay.
    @discardableResult func sendNow(reason: SendReason) async -> Bool {
        let (sharing, lastSentAt, lastAttemptAt) = await MainActor.run {
            let storage = Storage.shared
            return (storage.telemetryEnabled.value, storage.telemetryLastSentAt.value, storage.telemetryLastAttemptAt.value)
        }
        guard sharing else { return false }
        let now = Date()
        return await sendGate.runIfEligible(
            now: now,
            lastSentAt: lastSentAt,
            lastAttemptAt: lastAttemptAt,
            minimumInterval: Self.dailyInterval,
            retryInterval: Self.retryInterval,
            force: true,
            operation: { await self.send(reason: reason) },
            onAttempt: { await MainActor.run { Storage.shared.telemetryLastAttemptAt.value = now } },
            onSuccess: { await MainActor.run { self.recordSuccessfulSend() } }
        )
    }

    private func recordSuccessfulSend() {
        let storage = Storage.shared
        storage.telemetryLastSentAt.value = Date()
        storage.telemetryLastSentBuild.value = Self.buildIdentity
        storage.telemetryLastAttemptAt.value = nil
    }

    private func recordSuccessfulAnonymousSend() {
        let storage = Storage.shared
        storage.telemetryAnonymousLastSentAt.value = Date()
        storage.telemetryLastSentBuild.value = Self.buildIdentity
        storage.telemetryLastAttemptAt.value = nil
    }

    // MARK: - Payload

    /// The exact payload that would be POSTed right now. Pure function: useful
    /// both for sending and for the "What's sent" preview UI.
    func buildPayload() -> [String: Any] {
        let storage = Storage.shared
        let bd = BuildDetails.default

        var payload: [String: Any] = [:]

        payload["appVersion"] = Self.appVersion
        if !Self.commitSha.isEmpty {
            payload["commitSha"] = Self.commitSha
        }

        // Date-only (YYYY-MM-DD) prefix of the ISO8601 build date. Time is
        // dropped to keep the payload to a low-resolution build identifier.
        if let buildDate = Self.buildDate {
            payload["buildDate"] = buildDate
        }

        // Only signal we can actually verify: receipt-based TestFlight check.
        // macCatalyst is covered by `platform`; simulator is covered by the
        // `Simulator …` prefix on `device`. Anything else is a local Xcode
        // build (browser-build), which is just "isTestFlight == false".
        payload["isTestFlight"] = bd.isTestFlightBuild()

        payload["instance"] = AppConstants.appInstanceId
        payload["installId"] = installId()

        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            payload["idfv"] = idfv
        }

        payload["device"] = Self.hardwareIdentifier()
        payload["platform"] = Self.detectPlatform()
        payload["osVersion"] = UIDevice.current.systemVersion

        let dexcomUser = storage.shareUserName.value.trimmingCharacters(in: .whitespacesAndNewlines)
        payload["usesDexcom"] = !dexcomUser.isEmpty

        let nsURLRaw = storage.url.value.trimmingCharacters(in: .whitespacesAndNewlines)
        payload["usesNightscout"] = !nsURLRaw.isEmpty

        // Which closed-loop app is being followed (Loop / Trio / …). Field
        // omitted when device hasn't been detected yet; absence is the signal.
        let device = storage.device.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !device.isEmpty {
            payload["followingApp"] = device
        }

        payload["backgroundRefreshMethod"] = storage.backgroundRefreshType.value.rawValue

        // Selected user-preference fields. Picked for product-decision value;
        // none reveal personal or health information.
        payload["units"] = storage.units.value // "mg/dL" / "mmol/L"
        payload["remoteType"] = storage.remoteType.value.rawValue // which remote-command path
        payload["appearanceMode"] = storage.appearanceMode.value.rawValue // light / dark / system
        payload["contactEnabled"] = storage.contactEnabled.value // Contacts integration on?
        payload["calendarEnabled"] = !storage.calendarIdentifier.value.isEmpty // calendar selected?

        payload["coldLaunches7d"] = storage.telemetryColdLaunchTimes.value.count

        return payload
    }

    /// Everything the anonymous heartbeat carries, for the "What's sent"
    /// preview. The trigger varies per request.
    func anonymousPreview() -> [String: Any] {
        var preview: [String: Any] = [
            "appVersion": Self.appVersion,
            "installId": installId(),
            "reason": "what triggered the check-in, e.g. cold_launch",
        ]
        if !Self.commitSha.isEmpty {
            preview["commitSha"] = Self.commitSha
        }
        if let buildDate = Self.buildDate {
            preview["buildDate"] = buildDate
        }
        if let failure = Storage.shared.telemetryLastFailureReason.value {
            preview["lastFailureReason"] = failure
        }
        return preview
    }

    // MARK: - Send

    /// URL for `path` with the trigger reason and the previous attempt's
    /// failure category as query items.
    static func requestURL(baseURL: URL, path: String, reason: SendReason, lastFailureReason: String?) -> URL? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            return nil
        }
        var items = [URLQueryItem(name: "reason", value: reason.rawValue)]
        if let lastFailureReason, !lastFailureReason.isEmpty {
            items.append(URLQueryItem(name: "lastFailureReason", value: lastFailureReason))
        }
        components.queryItems = items
        return components.url
    }

    private func request(path: String, method: String, reason: SendReason) -> URLRequest? {
        guard let url = Self.requestURL(
            baseURL: Self.baseURL,
            path: path,
            reason: reason,
            lastFailureReason: Storage.shared.telemetryLastFailureReason.value
        ) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("Bearer \(Self.writeToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.appVersion, forHTTPHeaderField: "X-LoopFollow-Version")
        request.setValue(installId(), forHTTPHeaderField: "X-LoopFollow-InstallId")
        if !Self.commitSha.isEmpty {
            request.setValue(Self.commitSha, forHTTPHeaderField: "X-LoopFollow-CommitSha")
        }
        if let buildDate = Self.buildDate {
            request.setValue(buildDate, forHTTPHeaderField: "X-LoopFollow-BuildDate")
        }
        #if targetEnvironment(simulator)
            request.setValue("true", forHTTPHeaderField: "X-LoopFollow-Simulator")
        #endif
        return request
    }

    /// Performs `request` and returns success on 2xx. Any failure is stored
    /// as a short category that the next request reports.
    private func perform(_ request: URLRequest?, label: String) async -> Bool {
        let failureReason: String?
        do {
            failureReason = try await outcome(of: request, label: label)
        } catch {
            LogManager.shared.log(category: .telemetry, message: "\(label) error: \(error.localizedDescription)", isDebug: true)
            failureReason = "\(label)_request_failed"
        }
        await MainActor.run { Storage.shared.telemetryLastFailureReason.value = failureReason }
        return failureReason == nil
    }

    /// Nil on 2xx, otherwise the failure category.
    private func outcome(of request: URLRequest?, label: String) async throws -> String? {
        guard let request else { return "\(label)_request_url_failed" }
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            LogManager.shared.log(category: .telemetry, message: "\(label): non-HTTP response", isDebug: true)
            return "\(label)_non_http_response"
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            LogManager.shared.log(category: .telemetry, message: "\(label) status=\(http.statusCode)", isDebug: true)
            return "\(label)_http_\(http.statusCode)"
        }
        LogManager.shared.log(category: .telemetry, message: "\(label) ok status=\(http.statusCode)", isDebug: true)
        return nil
    }

    private func send(reason: SendReason) async -> Bool {
        let request: URLRequest? = await MainActor.run {
            guard let body = try? JSONSerialization.data(withJSONObject: self.buildPayload(), options: []) else {
                return nil
            }
            var request = self.request(path: "checkin", method: "POST", reason: reason)
            request?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request?.httpBody = body
            return request
        }
        return await perform(request, label: "checkin")
    }

    private func sendAnonymous(reason: SendReason) async -> Bool {
        let request = await MainActor.run { self.request(path: "anonymous", method: "GET", reason: reason) }
        return await perform(request, label: "anonymous")
    }

    // MARK: - Helpers

    /// Salted SHA-256, truncated to 16 hex chars (64 bits).
    static func hashed(_ raw: String) -> String {
        let canonical = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let input = Data((salt + canonical).utf8)
        let digest = SHA256.hash(data: input)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// `iPhone15,2`-style identifier from `utsname.machine`. Returns
    /// `Simulator <SIMULATOR_MODEL_IDENTIFIER>` on the simulator so analysis
    /// can ignore those rows.
    static func hardwareIdentifier() -> String {
        #if targetEnvironment(simulator)
            let env = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Unknown"
            return "Simulator \(env)"
        #else
            var sys = utsname()
            uname(&sys)
            let mirror = Mirror(reflecting: sys.machine)
            let machine = mirror.children.reduce(into: "") { acc, child in
                guard let v = child.value as? Int8, v != 0 else { return }
                acc.append(Character(UnicodeScalar(UInt8(v))))
            }
            return machine.isEmpty ? "Unknown" : machine
        #endif
    }

    static func detectPlatform() -> String {
        #if targetEnvironment(macCatalyst)
            return "macCatalyst"
        #else
            switch UIDevice.current.userInterfaceIdiom {
            case .pad: return "iPadOS"
            default: return "iOS"
            }
        #endif
    }
}

// MARK: - TelemetryPreviewView

/// Renders the exact payload that would be sent right now, with a copy
/// button. Linked to from the Diagnostics section in Settings and from the
/// consent sheet's "See exactly what's sent" button.
struct TelemetryPreviewView: View {
    @State private var jsonText: String = ""
    @State private var sharing = Storage.shared.telemetryEnabled.value

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(sharing
                    ? "Below is the exact JSON object that LoopFollow would send to lf.bjorkert.se right now."
                    : "Usage stats are off. LoopFollow sends only this minimal check-in to lf.bjorkert.se, once a day and after installing a new build.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                Text(jsonText)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)

                Button {
                    UIPasteboard.general.string = jsonText
                } label: {
                    Label("Copy JSON", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("What's sent")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sharing = Storage.shared.telemetryEnabled.value
            jsonText = Self.renderPayload(sharing: sharing)
        }
    }

    private static func renderPayload(sharing: Bool) -> String {
        let payload = sharing ? TelemetryClient.shared.buildPayload() : TelemetryClient.shared.anonymousPreview()
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else { return "Unable to render payload." }
        return text
    }
}

// MARK: - TelemetryPrivacyView

/// In-app summary so users don't have to leave the app to understand
/// what is collected.
struct TelemetryPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Endpoint")
                        .font(.headline)
                    Text("Usage stats are on by default. Once a day, and after installing a new build, the app sends a small JSON object to https://lf.bjorkert.se. The endpoint is self-hosted by the maintainer; no third-party analytics service is involved.")
                }

                Group {
                    Text("What is sent")
                        .font(.headline)
                    Text("App version, build commit and build date, whether this is a TestFlight build, the install instance number, a random install ID created by this app, an Apple-supplied per-vendor identifier (IDFV) that resets when all this developer's apps are removed from the device, the hardware identifier (e.g. iPhone15,2), the platform (iPhone, iPad or Mac), the iOS version, and how many times the app was started from scratch in the last 7 days. Whether Nightscout and Dexcom are configured (yes/no — no URLs or usernames). Which app you're following (Loop, Trio, etc), if known. A small set of preference flags (units, appearance mode, calendar/contact integration enabled, remote-command type, background refresh method). The full JSON is visible under Diagnostics → What's sent.")
                }

                Group {
                    Text("What stays on your device")
                        .font(.headline)
                    Text("All glucose, insulin, and carb data. Your Nightscout URL and API token. Your Dexcom credentials. Remote-command secrets and APNS keys. Time zone. Location data. Logs — these are never sent automatically; the Settings → Logs sharing flow is unchanged and only triggered by you.")
                }

                Group {
                    Text("Frequency")
                        .font(.headline)
                    Text("Once every 24 hours, plus once after installing a new build. Each request also says what triggered it (for example app launch or new build) and, if the previous attempt failed, a short error category. The check runs when the app launches, when it comes to the foreground, and while it is refreshing in the background.")
                }

                Group {
                    Text("Opt out")
                        .font(.headline)
                    Text("Use the Send anonymous usage stats toggle above. Turning it off is immediate and persistent. After that, the app sends only a minimal check-in, once a day and after installing a new build, so the developers can count how many installs run each version: the app version, build commit and build date, the random install ID, and the trigger and error category described above. It contains no device, settings, or health information.")
                }

                Group {
                    Text("Source")
                        .font(.headline)
                    Text("LoopFollow/Helpers/Telemetry.swift on GitHub.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
