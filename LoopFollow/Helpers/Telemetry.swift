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
    private static let dailyInterval: TimeInterval = 24 * 60 * 60

    private init() {}

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

    /// True when the running build's commit SHA differs from the SHA recorded
    /// at the last successful send. Used at startup to fire one immediate
    /// ping after an app update — the regular 24h scheduler can't tell that
    /// the build changed and would otherwise wait out the previous interval.
    func buildShaChangedSinceLastSend() -> Bool {
        let currentSha = BuildDetails.default.commitSha ?? ""
        return Storage.shared.telemetryLastSentSha.value != currentSha
    }

    /// Wires telemetry into TaskScheduler. Called once on app start (from
    /// AppDelegate.didFinishLaunchingWithOptions) and again after each tick.
    /// First run is computed from `telemetryLastSentAt`: a relaunch 6h after
    /// the previous send waits 18h; a relaunch after 25h fires on the next
    /// timer tick (TaskScheduler treats a past nextRun as "fire soon"). Each
    /// fired tick reschedules itself for +24h, giving the steady-state
    /// cadence while the app keeps running.
    ///
    /// Bails out without scheduling if the user hasn't decided on consent
    /// yet or has opted out — there's nothing for the timer to do, and
    /// scheduling for "now" with `lastSentAt` still nil would tight-loop
    /// (fire → maybeSend bails → reschedule → fire …).
    func scheduleRecurring() {
        let storage = Storage.shared
        guard storage.telemetryConsentDecisionMade.value,
              storage.telemetryEnabled.value
        else {
            return
        }

        let nextRun: Date
        if let last = storage.telemetryLastSentAt.value {
            nextRun = last.addingTimeInterval(Self.dailyInterval)
        } else {
            // Consent given but we've never landed a successful send
            // (network down at first launch, server hiccup, etc). Retry in
            // a minute — bounded so a persistently failing send doesn't
            // turn into a busy loop.
            nextRun = Date().addingTimeInterval(60)
        }

        TaskScheduler.shared.scheduleTask(id: .telemetry, nextRun: nextRun) {
            Task.detached {
                await TelemetryClient.shared.maybeSend()
                TelemetryClient.shared.scheduleRecurring()
            }
        }
    }

    /// Single entry point used by all callers (scheduler tick, consent-yes,
    /// startup SHA-change). Gated only by consent + opt-in toggle; *when* to
    /// send is the caller's decision (the scheduler handles the 24h cadence
    /// by setting `nextRun`; startup handles the SHA-change shortcut).
    func maybeSend() async {
        let storage = Storage.shared
        guard storage.telemetryConsentDecisionMade.value else { return }
        guard storage.telemetryEnabled.value else { return }
        await send()
    }

    /// The exact payload that would be POSTed right now. Pure function: useful
    /// both for sending and for the "What's sent" preview UI.
    func buildPayload() -> [String: Any] {
        let storage = Storage.shared
        let info = Bundle.main.infoDictionary ?? [:]
        let bd = BuildDetails.default

        var payload: [String: Any] = [:]

        if let v = info["CFBundleShortVersionString"] as? String { payload["appVersion"] = v }

        // Date-only (YYYY-MM-DD) prefix of the ISO8601 build date. Time is
        // dropped to keep the payload to a low-resolution build identifier.
        if let date = bd.buildDateString, date.count >= 10 {
            payload["buildDate"] = String(date.prefix(10))
        }

        // Only signal we can actually verify: receipt-based TestFlight check.
        // macCatalyst is covered by `platform`; simulator is covered by the
        // `Simulator …` prefix on `device`. Anything else is a local Xcode
        // build (browser-build), which is just "isTestFlight == false".
        payload["isTestFlight"] = bd.isTestFlightBuild()

        payload["instance"] = AppConstants.appInstanceId

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
                let sha = BuildDetails.default.commitSha ?? ""
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
                    Text("Once a day (or after a new build), the app sends a small JSON object to https://lf.bjorkert.se. The endpoint is self-hosted by the maintainer; no third-party analytics service is involved.")
                }

                Group {
                    Text("What is sent")
                        .font(.headline)
                    Text("App version, build date, whether this is a TestFlight build, the install instance number, an Apple-supplied per-vendor identifier (IDFV) that resets when all this developer's apps are removed from the device, the hardware identifier (e.g. iPhone15,2), and iOS version. Whether Nightscout and Dexcom are configured (yes/no — no URLs or usernames). Which app you're following (Loop, Trio, etc), if known. A small set of preference flags (units, appearance mode, calendar/contact integration enabled, remote-command type, background refresh method). The full JSON is visible under Diagnostics → What's sent.")
                }

                Group {
                    Text("What stays on your device")
                        .font(.headline)
                    Text("All glucose, insulin, and carb data. Your Nightscout URL and API token. Your Dexcom credentials. Remote-command secrets and APNS keys. Time zone. Location data. Logs — these are never sent automatically; the Settings → Logs sharing flow is unchanged and only triggered by you.")
                }

                Group {
                    Text("Frequency")
                        .font(.headline)
                    Text("Once every 24 hours, plus once after installing a new build. The check runs in the background while the app is active or refreshing in the background.")
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
                    Text("You can choose to share anonymous information with the developers to help improve LoopFollow—such as app and iOS version, device type, which app you're following, and a few settings. Your health data, credentials, time zone, and logs remain on your device.")

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
                        // Fire the inaugural ping immediately, then start the
                        // 24h scheduled cadence ticking from that send.
                        Task.detached {
                            await TelemetryClient.shared.maybeSend()
                            TelemetryClient.shared.scheduleRecurring()
                        }
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
