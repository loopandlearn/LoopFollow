// LoopFollow
// LogRedactor.swift

import CryptoKit
import Foundation

/// Helpers for masking secrets before they hit the log file. The "share logs"
/// feature exposes the on-disk log to the user, so anything sensitive that
/// flows through `LogManager.log` must be reduced to a non-recoverable form
/// while keeping enough signal (short suffix, host, fingerprint) to correlate
/// events during debugging.
enum LogRedactor {
    /// Last `keep` characters of `secret`, prefixed with `…`. Matches the
    /// existing `.suffix(8)` convention used in `LiveActivityManager`.
    static func tail(_ secret: String, keep: Int = 8) -> String {
        if secret.isEmpty { return "(empty)" }
        if secret.count <= keep { return "(redacted)" }
        return "…\(secret.suffix(keep))"
    }

    /// First `keep` characters of `secret`, suffixed with `…`. Matches the
    /// existing `.prefix(8)` convention used in `LoopAPNSService`.
    static func head(_ secret: String, keep: Int = 8) -> String {
        if secret.isEmpty { return "(empty)" }
        if secret.count <= keep { return "(redacted)" }
        return "\(secret.prefix(keep))…"
    }

    /// Known managed-Nightscout host suffixes. When a URL's host ends in one
    /// of these, the leading subdomain (which identifies the user) is masked
    /// and the suffix is kept so engineers can tell which platform the user
    /// is on. Anything else is treated as self-hosted and reduced to the TLD.
    private static let knownHostSuffixes: [String] = [
        "nightscoutpro.com",
        "10be.de",
        "herokuapp.com",
    ]

    /// Keep scheme + a redacted host hint, drop path and query. The Nightscout
    /// token rides in `?token=` and the host itself identifies the user when
    /// they're on a managed platform, so we mask the subdomain and keep only
    /// the platform suffix (or just the TLD for self-hosted setups).
    static func url(_ raw: String) -> String {
        if raw.isEmpty { return "(empty)" }
        if let u = URL(string: raw), let host = u.host {
            let scheme = u.scheme.map { "\($0)://" } ?? ""
            return "\(scheme)\(maskHost(host))/…"
        }
        return "(redacted)"
    }

    private static func maskHost(_ host: String) -> String {
        // IPv4 / IPv6 / bracketed — drop entirely.
        if host.range(of: "^\\d+\\.\\d+\\.\\d+\\.\\d+$", options: .regularExpression) != nil { return "***" }
        if host.contains(":") || host.hasPrefix("[") { return "***" }

        let lower = host.lowercased()
        for suffix in knownHostSuffixes {
            if lower == suffix || lower.hasSuffix("." + suffix) {
                return "***." + suffix
            }
        }

        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count >= 2, let tld = parts.last, !tld.isEmpty {
            return "***." + String(tld)
        }
        return "***"
    }

    /// Apple Developer Key ID — 10-char uppercase alphanumeric. Reveals
    /// last 2 chars only.
    static func keyId(_ keyId: String) -> String {
        if keyId.isEmpty { return "(empty)" }
        if keyId.count <= 2 { return "(redacted)" }
        return "…\(keyId.suffix(2))"
    }

    /// Apple Team ID — 10-char uppercase alphanumeric. Reveals last 2 chars.
    static func teamId(_ teamId: String) -> String {
        keyId(teamId)
    }

    /// App bundle id ("com.example.MyApp"). Mask the middle component(s) but
    /// keep the leading TLD and trailing app name so suffixes like
    /// `.watchkitapp` or `.push-type.liveactivity` remain visible.
    static func bundleId(_ id: String) -> String {
        if id.isEmpty { return "(empty)" }
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return "(redacted)" }
        var masked = [String]()
        masked.append(String(parts[0]))
        for _ in 1 ..< parts.count - 1 {
            masked.append("***")
        }
        masked.append(String(parts[parts.count - 1]))
        return masked.joined(separator: ".")
    }

    /// Username (Dexcom Share, etc.). Preserves first character and any
    /// `@domain` suffix shape so engineers can tell email-shaped from not.
    static func username(_ name: String) -> String {
        if name.isEmpty { return "(empty)" }
        if name.contains("@") {
            let parts = name.split(separator: "@", maxSplits: 1).map(String.init)
            let local = parts[0]
            let domain = parts.count > 1 ? parts[1] : ""
            let firstLocal = local.first.map(String.init) ?? "?"
            let firstDomain = domain.first.map(String.init) ?? "?"
            return "\(firstLocal)***@\(firstDomain)***"
        }
        let first = name.first.map(String.init) ?? "?"
        return "\(first)***"
    }

    /// Sweep an arbitrary message string for high-confidence secret shapes.
    /// Idempotent. Run by `LogManager.log` on every line before write.
    static func sweep(_ message: String) -> String {
        var out = message
        out = redactPEM(out)
        out = redactTokenQuery(out)
        out = redactJWT(out)
        return out
    }

    /// Replace any `?token=…` or `&token=…` value with `***` (case-insensitive).
    private static func redactTokenQuery(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "([?&]token=)[^&\\s\"'<>]+",
            options: [.caseInsensitive]
        ) else { return s }
        let range = NSRange(s.startIndex ..< s.endIndex, in: s)
        return regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "$1***")
    }

    /// Collapse the body of a PEM PRIVATE KEY block to `(redacted)`.
    private static func redactPEM(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----",
            options: []
        ) else { return s }
        let range = NSRange(s.startIndex ..< s.endIndex, in: s)
        return regex.stringByReplacingMatches(
            in: s, options: [], range: range,
            withTemplate: "-----BEGIN PRIVATE KEY----- (redacted) -----END PRIVATE KEY-----"
        )
    }

    /// Collapse the middle segment of a JWT (`ey…\.ey…\.…`).
    private static func redactJWT(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "ey[A-Za-z0-9_-]{8,}\\.ey[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}",
            options: []
        ) else { return s }
        let range = NSRange(s.startIndex ..< s.endIndex, in: s)
        return regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "ey…<jwt>…")
    }

    /// Non-reversible fingerprint for opaque blobs we can't safely log
    /// (settings JSON, scanned QR code contents, etc.).
    static func fingerprint(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "\(data.count) bytes, sha256=\(hex.prefix(8))…"
    }

    static func fingerprint(_ string: String) -> String {
        fingerprint(Data(string.utf8))
    }
}
