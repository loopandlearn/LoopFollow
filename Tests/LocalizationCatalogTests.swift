// LoopFollow
// LocalizationCatalogTests.swift

import Foundation
@testable import LoopFollow
import Testing

/// Guards the String Catalogs checked into the repo. Reads the JSON source files, not the
/// compiled bundle, so it runs without a device language switch.
struct LocalizationCatalogTests {
    /// Repo root derived from this file's location (Tests/LocalizationCatalogTests.swift).
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let catalogs = ["LoopFollow/Resources/Localizable.xcstrings"]
    static let languages = ["tr"]

    private struct Catalog {
        let sourceLanguage: String
        let strings: [String: [String: Any]]
    }

    private static func load(_ path: String) throws -> Catalog {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(path))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: [String: Any]])
        let source = try #require(json["sourceLanguage"] as? String)
        return Catalog(sourceLanguage: source, strings: strings)
    }

    private static func unit(_ entry: [String: Any], _ language: String) -> (state: String, value: String)? {
        guard let localizations = entry["localizations"] as? [String: Any],
              let lang = localizations[language] as? [String: Any],
              let unit = lang["stringUnit"] as? [String: Any],
              let state = unit["state"] as? String,
              let value = unit["value"] as? String else { return nil }
        return (state, value)
    }

    /// Keys marked "Don't translate" in Xcode are skipped.
    private static func translatable(_ entry: [String: Any]) -> Bool {
        (entry["shouldTranslate"] as? Bool) ?? true
    }

    /// printf-style specifiers, e.g. %lld, %@, %.1f, %2$@. Returns (positionalIndex?, specifier).
    /// The positional group only matches digits followed by "$", so a width like "%2d" is not positional.
    /// The space flag is deliberately not accepted so prose such as "% and" is not read as a specifier.
    private static func placeholders(in s: String) -> [(Int?, String)] {
        let pattern = #"%(?:(\d+)\$)?([-+0#]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDiuUxXoOfeEgGcCsSpaAF])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in
            guard let specRange = Range(m.range(at: 2), in: s) else { return nil }
            let index = Range(m.range(at: 1), in: s).flatMap { Int(s[$0]) }
            return (index, String(s[specRange]))
        }
    }

    @Test("every translatable key has a translated value", arguments: Self.catalogs)
    func allKeysTranslated(path: String) throws {
        let catalog = try Self.load(path)
        #expect(catalog.sourceLanguage == "en")
        var missing: [String] = []
        for (key, entry) in catalog.strings where Self.translatable(entry) {
            for language in Self.languages {
                guard let t = Self.unit(entry, language), t.state == "translated",
                      !t.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { missing.append("[\(language)] \(key)"); continue }
            }
        }
        #expect(missing.isEmpty, Comment(rawValue: "Missing translations (\(missing.count)):\n" + missing.sorted().joined(separator: "\n")))
    }

    @Test("format placeholders survive translation", arguments: Self.catalogs)
    func placeholdersPreserved(path: String) throws {
        let catalog = try Self.load(path)
        var problems: [String] = []
        for (key, entry) in catalog.strings where Self.translatable(entry) {
            let source = Self.placeholders(in: key)
            guard !source.isEmpty else { continue }
            for language in Self.languages {
                guard let t = Self.unit(entry, language) else { continue }
                let target = Self.placeholders(in: t.value)
                if source.map(\.1).sorted() != target.map(\.1).sorted() {
                    problems.append("[\(language)] \(key) -> \(t.value)")
                    continue
                }
                let reordered = source.map(\.1) != target.map(\.1)
                if source.count > 1, reordered, target.contains(where: { $0.0 == nil }) {
                    problems.append("[\(language)] reordered without positional indexes: \(key) -> \(t.value)")
                }
            }
        }
        #expect(problems.isEmpty, Comment(rawValue: "Placeholder problems:\n" + problems.joined(separator: "\n")))
    }

    @Test("no stale keys linger in the catalog", arguments: Self.catalogs)
    func noStaleKeys(path: String) throws {
        let catalog = try Self.load(path)
        let stale = catalog.strings.filter { ($0.value["extractionState"] as? String) == "stale" }.map(\.key)
        #expect(stale.isEmpty, Comment(rawValue: "Stale keys (remove them from the catalog):\n" + stale.sorted().joined(separator: "\n")))
    }
}
