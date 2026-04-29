// LoopFollow
// Telemetry.swift

import CryptoKit
import Foundation
import SwiftUI
import UIKit

// MARK: - TelemetryClient

final class TelemetryClient {
    static let shared = TelemetryClient()

    private static let endpoint = URL(string: "https://lf.bjorkert.se/api/telemetry/checkin")!
    private static let salt = "lf-telemetry"
    private static let weeklyInterval: TimeInterval = 7 * 24 * 60 * 60

    /// Lazily generates and persists the install's permanent clientId on
    /// first construction. `Storage.telemetryClientId` is nil until this
    /// runs; assigning to .value goes through StorageValue's didSet, which
    /// is what actually writes to UserDefaults.
    private init() {
        let storage = Storage.shared
        if storage.telemetryClientId.value == nil {
            storage.telemetryClientId.value = UUID().uuidString
        }
    }

    /// Records a cold launch in a sliding 7-day window of timestamps. Called
    /// from AppDelegate.didFinishLaunchingWithOptions on every process start
    /// (foreground or background). The count of entries in the window is sent
    /// as `coldLaunches7d` in each ping, giving a "how often is iOS recycling
    /// or killing this process" signal that's directly comparable across
    /// pings regardless of the cadence between them.
    func recordColdLaunch(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.weeklyInterval)
        var recent = Storage.shared.telemetryColdLaunchTimes.value
        recent.removeAll { $0 < cutoff }
        recent.append(now)
        Storage.shared.telemetryColdLaunchTimes.value = recent
    }

    /// Static write token, committed in source. The LoopFollow repo is public,
    /// so this string is public too. The backend treats it as a "front door
    /// sign" rather than a secret: TLS, NGINX rate limit (60 req/min/IP),
    /// strict schema validation, and an insert+find-only MongoDB role bound
    /// any abuse to harmless duplicate-row inserts.
    private static let writeToken = "RsEDJ8RoOs7HHZ_XGOdI1sY3Yuv6iPnRRk7tg-NlCAg"

    /// Re-entrancy lock so concurrent call sites (e.g. AppDelegate cold-launch
    /// hook + SceneDelegate foreground hook firing in the same activation)
    /// can't both POST. The first one through atomically flips this true; the
    /// second sees it and bails. Reset in a `defer` so any path through `send`
    /// — success, failure, throw — clears it.
    private let sendingLock = NSLock()
    private var isSending = false

    /// Returns true if the configured trigger conditions are met (weekly elapsed
    /// or build SHA changed since the last successful send).
    func shouldSendNow(now: Date = Date()) -> Bool {
        let storage = Storage.shared
        let weekElapsed = storage.telemetryLastSentAt.value
            .map { now.timeIntervalSince($0) > Self.weeklyInterval } ?? true
        let currentSha = BuildDetails.default.commitSha ?? ""
        let buildChanged = storage.telemetryLastSentSha.value != currentSha
        return weekElapsed || buildChanged
    }

    /// Single entry point used by all triggers (cold launch, foreground, etc).
    /// Skips silently if telemetry is disabled, consent isn't yet recorded, or
    /// trigger conditions aren't met. Safe to call from any thread; concurrent
    /// calls collapse into one network request via `sendingLock`.
    func maybeSend() async {
        let storage = Storage.shared
        guard storage.telemetryConsentDecisionMade.value else { return }
        guard storage.telemetryEnabled.value else { return }
        guard shouldSendNow() else { return }

        sendingLock.lock()
        if isSending {
            sendingLock.unlock()
            return
        }
        isSending = true
        sendingLock.unlock()

        defer {
            sendingLock.lock()
            isSending = false
            sendingLock.unlock()
        }

        await send()
    }

    /// The exact payload that would be POSTed right now. Pure function: useful
    /// both for sending and for the "What's sent" preview UI.
    func buildPayload() -> [String: Any] {
        let storage = Storage.shared
        let info = Bundle.main.infoDictionary ?? [:]
        let bd = BuildDetails.default

        var payload: [String: Any] = [:]

        // Guaranteed non-nil after TelemetryClient.shared has been constructed
        // — see private init(). Empty fallback is defensive; the server's
        // UUID regex would reject an empty string with 400, surfacing the
        // invariant break via the reject-rate Telegram alert.
        payload["clientId"] = storage.telemetryClientId.value ?? ""

        if let v = info["CFBundleShortVersionString"] as? String { payload["appVersion"] = v }
        if let v = info["CFBundleVersion"] as? String { payload["buildNumber"] = v }

        if let branch = bd.branch { payload["buildBranch"] = branch }
        if let sha = bd.commitSha { payload["buildSha"] = sha }
        if let date = bd.buildDateString { payload["buildDate"] = date }

        // Only signal we can actually verify: receipt-based TestFlight check.
        // macCatalyst is covered by `platform`; simulator is covered by the
        // `Simulator …` prefix on `device`. Anything else is a local Xcode
        // build (browser-build), which is just "isTestFlight == false".
        payload["isTestFlight"] = bd.isTestFlightBuild()

        if let team = bd.teamID, !team.isEmpty {
            payload["hashedTeamId"] = Self.hashed(team)
        }

        payload["instance"] = AppConstants.appInstanceId

        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            payload["hashedIDFV"] = Self.hashed(idfv)
        }

        payload["device"] = Self.hardwareIdentifier()
        payload["platform"] = Self.detectPlatform()
        payload["osVersion"] = UIDevice.current.systemVersion
        payload["timeZone"] = TimeZone.current.identifier

        // hashedDexcomAccount / hashedNightscoutHost are sent ONLY when those
        // backends are configured. Their presence-or-absence is itself the
        // "do you use Dexcom / Nightscout?" signal — no separate booleans.

        let dexcomUser = storage.shareUserName.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dexcomUser.isEmpty {
            payload["hashedDexcomAccount"] = Self.hashed(dexcomUser)
        }

        let nsURLRaw = storage.url.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nsURLRaw.isEmpty, let host = URL(string: nsURLRaw)?.host, !host.isEmpty {
            payload["hashedNightscoutHost"] = Self.hashed(host)
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

    /// Build payload, POST it, update last-sent state on 2xx. Fire-and-forget;
    /// errors are logged at debug level only and never surfaced to the UI.
    func send() async {
        let storage = Storage.shared
        let payload = buildPayload()
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            LogManager.shared.log(category: .telemetry, message: "skip send: payload not JSON-serializable", isDebug: true)
            return
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Self.writeToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                LogManager.shared.log(category: .telemetry, message: "send: non-HTTP response", isDebug: true)
                return
            }
            if (200 ..< 300).contains(http.statusCode) {
                let now = Date()
                let sha = (payload["buildSha"] as? String) ?? ""
                storage.telemetryLastSentAt.value = now
                storage.telemetryLastSentSha.value = sha
                LogManager.shared.log(category: .telemetry, message: "send ok status=\(http.statusCode)", isDebug: true)
            } else {
                LogManager.shared.log(category: .telemetry, message: "send non-2xx status=\(http.statusCode)", isDebug: true)
            }
        } catch {
            LogManager.shared.log(category: .telemetry, message: "send error: \(error.localizedDescription)", isDebug: true)
        }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Below is the exact JSON object that LoopFollow would send to lf.bjorkert.se right now.")
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
        .onAppear { jsonText = Self.renderPayload() }
    }

    private static func renderPayload() -> String {
        let payload = TelemetryClient.shared.buildPayload()
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
                    Text("Once a week (or after a new build), the app sends a small JSON object to https://lf.bjorkert.se. The endpoint is self-hosted by the maintainer; no third-party analytics service is involved.")
                }

                Group {
                    Text("What is sent")
                        .font(.headline)
                    Text("App version, build SHA and date, whether this is a TestFlight build, the Apple development team that signed this build (anonymized), the install instance number, a per-device anonymized identifier, the hardware identifier (e.g. iPhone15,2), iOS version, and time zone. An anonymized identifier for your Nightscout site and your Dexcom username is also sent — but only when those are configured. The full JSON is visible under Diagnostics → What's sent.")
                }

                Group {
                    Text("What stays on your device")
                        .font(.headline)
                    Text("All glucose, insulin, and carb data. Your Nightscout URL and API token. Your Dexcom credentials. Remote-command secrets and APNS keys. Location data. Logs — these are never sent automatically; the Settings → Logs sharing flow is unchanged and only triggered by you.")
                }

                Group {
                    Text("Frequency")
                        .font(.headline)
                    Text("Once every 7 days, plus once after each new build. The check runs on every app launch (including silent-push wake-ups and background app refresh) and on every foreground. Whichever launch is first eligible will send.")
                }

                Group {
                    Text("Opt out")
                        .font(.headline)
                    Text("Use the Send anonymous usage stats toggle above. Turning it off is immediate and persistent.")
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

// MARK: - TelemetryConsentView

/// One-time prompt shown the first time the app foregrounds after install
/// or after an update from a pre-telemetry version.
struct TelemetryConsentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("You can choose to share anonymous information with the developers to help improve LoopFollow—such as app and iOS version, device type, time zone, and a few settings. Your health data, credentials, and logs remain on your device.")

                    Text("You can change this any time in Settings → Diagnostics.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    NavigationLink {
                        TelemetryPreviewView()
                    } label: {
                        Label("See exactly what's sent", systemImage: "doc.text.magnifyingglass")
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Help us help you!")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        Storage.shared.telemetryEnabled.value = true
                        Storage.shared.telemetryConsentDecisionMade.value = true
                        // Fire one ping right away so the chosen-yes state isn't
                        // delayed until the next foreground / cold launch.
                        Task.detached { await TelemetryClient.shared.maybeSend() }
                        dismiss()
                    } label: {
                        Text("Yes, send anonymous stats")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Storage.shared.telemetryEnabled.value = false
                        Storage.shared.telemetryConsentDecisionMade.value = true
                        dismiss()
                    } label: {
                        Text("No thanks")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                .background(.bar)
            }
        }
    }
}
