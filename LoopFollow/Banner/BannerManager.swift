// LoopFollow
// BannerManager.swift

import Foundation
import ShareClient

/// Identifies who produced a banner message. Each source owns at most one
/// message at a time; reporting a new message for a source replaces its old one.
enum BannerSource: Hashable {
    case nightscout
    case dexcom
    case custom(String)
}

enum BannerSeverity: Int, Comparable {
    case info
    case warning
    case error

    static func < (lhs: BannerSeverity, rhs: BannerSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct BannerMessage: Equatable, Identifiable {
    let id: UUID
    let source: BannerSource
    let severity: BannerSeverity
    let text: String
    let timestamp: Date
}

/// App-wide banner state. Producers call `report`/`clear`; the view layer
/// observes `Observable.shared.activeBanner` and calls `dismissCurrent()`.
final class BannerManager {
    static let shared = BannerManager()

    /// How long a user dismissal suppresses a still-occurring error before it re-appears.
    static let dismissCooldown: TimeInterval = 30 * 60

    /// Minimum time between Nightscout diagnostic probes (status.json calls).
    private static let diagnosticInterval: TimeInterval = 5 * 60

    // All state is read and mutated on the main queue only.
    private var messages: [BannerSource: BannerMessage] = [:]
    private var dismissals: [BannerSource: (until: Date, text: String)] = [:]
    private var lastNightscoutDiagnostic: Date?

    private init() {}

    func report(source: BannerSource, severity: BannerSeverity = .error, text: String) {
        DispatchQueue.main.async {
            if let existing = self.messages[source], existing.text == text, existing.severity == severity {
                // Same problem re-reported (fetches retry every 10-60 s): keep the
                // message untouched so the banner doesn't re-animate, but publish in
                // case a dismissal cooldown has expired since the last report.
            } else {
                // A different problem: show it even if the previous one was dismissed.
                self.dismissals[source] = nil
                self.messages[source] = BannerMessage(
                    id: UUID(),
                    source: source,
                    severity: severity,
                    text: text,
                    timestamp: Date()
                )
            }
            self.publish()
        }
    }

    func clear(_ source: BannerSource) {
        DispatchQueue.main.async {
            guard self.messages[source] != nil || self.dismissals[source] != nil else { return }
            self.messages[source] = nil
            self.dismissals[source] = nil
            self.publish()
        }
    }

    func dismissCurrent() {
        DispatchQueue.main.async {
            guard let current = Observable.shared.activeBanner.value else { return }
            self.dismissals[current.source] = (Date().addingTimeInterval(Self.dismissCooldown), current.text)
            self.publish()
        }
    }

    /// Classifies a failed Nightscout fetch by probing status.json, so the banner
    /// can say *why* it failed (invalid token, site not found, no network, ...)
    /// instead of showing a generic decode/transport error.
    func reportNightscoutFetchFailure(_ underlying: Error) {
        DispatchQueue.main.async {
            if let last = self.lastNightscoutDiagnostic, Date().timeIntervalSince(last) < Self.diagnosticInterval {
                return
            }
            self.lastNightscoutDiagnostic = Date()

            NightscoutUtils.verifyURLAndToken { error, _, _, _ in
                if let error = error {
                    if case .emptyAddress = error {
                        // URL was removed while a fetch was in flight — not an error state.
                        self.clear(.nightscout)
                        return
                    }
                    self.report(
                        source: .nightscout,
                        severity: .error,
                        text: "Nightscout: \(error.localizedDescription)"
                    )
                } else {
                    // Server reachable and token accepted, yet the data fetch failed.
                    LogManager.shared.log(
                        category: .nightscout,
                        message: "Nightscout diagnostic OK but data fetch failed: \(underlying)",
                        limitIdentifier: "Nightscout diagnostic OK but data fetch failed"
                    )
                    self.report(
                        source: .nightscout,
                        severity: .warning,
                        text: "Nightscout: data download failed, but the server is reachable. Retrying automatically."
                    )
                }
            }
        }
    }

    func reportDexcomFailure(_ error: ShareError, nightscoutFallback: Bool) {
        var text: String
        switch error {
        case let .loginError(errorCode):
            // Dexcom has returned both legacy "SSO_Authenticate…" codes and newer
            // ones like "AccountPasswordInvalid" — match on the common substrings.
            if errorCode.contains("AccountNotFound") {
                text = "Dexcom Share: account not found — check your username."
            } else if errorCode.contains("PasswordInvalid") {
                text = "Dexcom Share: incorrect username or password."
            } else if errorCode.contains("MaxAttempts") {
                text = "Dexcom Share: too many failed login attempts — temporarily locked out."
            } else {
                text = "Dexcom Share: login failed (\(errorCode))."
            }
        case .httpError:
            text = "Dexcom Share: network error while downloading."
        case .fetchError, .dataError, .dateError:
            text = "Dexcom Share: could not download readings."
        }

        if nightscoutFallback {
            text += " Using Nightscout as backup."
        }
        report(source: .dexcom, severity: nightscoutFallback ? .warning : .error, text: text)
    }

    /// Pushes the highest-priority non-dismissed message to the UI.
    private func publish() {
        let now = Date()
        let candidate = messages.values
            .filter { message in
                guard let dismissal = dismissals[message.source] else { return true }
                return now >= dismissal.until || dismissal.text != message.text
            }
            .max { lhs, rhs in
                (lhs.severity, lhs.timestamp) < (rhs.severity, rhs.timestamp)
            }

        if Observable.shared.activeBanner.value != candidate {
            Observable.shared.activeBanner.set(candidate)
        }
    }
}
