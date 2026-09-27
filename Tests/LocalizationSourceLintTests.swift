// LoopFollow
// LocalizationSourceLintTests.swift

import Foundation
@testable import LoopFollow
import Testing

/// Source-level guards for patterns that silently defeat localization.
struct LocalizationSourceLintTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let sourceRoots = ["LoopFollow", "Shared", "LoopFollowLAExtension"]

    private static func swiftFiles() throws -> [URL] {
        var files: [URL] = []
        for root in sourceRoots {
            let dir = repoRoot.appendingPathComponent(root)
            guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in e where url.pathExtension == "swift" { files.append(url) }
        }
        return files
    }

    /// `Text("a " + "b")` resolves to the String overload of Text, so neither literal is ever
    /// looked up in the catalog even though the extractor may still emit the first one as a key.
    @Test("no Text literal is built from two string literals joined with +")
    func noConcatenatedTextLiterals() throws {
        let pattern = #"Text\("(?:[^"\\]|\\.)*"\s*\+\s*"#
        let regex = try NSRegularExpression(pattern: pattern)
        var hits: [String] = []
        for file in try Self.swiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for m in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let r = Range(m.range, in: source) else { continue }
                // Only flag when the next token after "+" is another string literal.
                let rest = source[r.upperBound...].drop(while: { $0 == " " || $0 == "\n" || $0 == "\t" })
                guard rest.first == "\"" else { continue }
                let line = source[..<r.lowerBound].filter { $0 == "\n" }.count + 1
                hits.append("\(file.lastPathComponent):\(line)")
            }
        }
        #expect(hits.isEmpty, Comment(rawValue: "Merge these into one literal so they localize:\n" + hits.joined(separator: "\n")))
    }

    /// Same rule as Scripts/localization/scan_keys.py: every plain string literal passed as the
    /// first argument of a listed API must exist as a key in the catalog.
    @Test("every literal passed to a localized API is a catalog key")
    func scannedLiteralsExistInCatalog() throws {
        let listURL = Self.repoRoot.appendingPathComponent("Scripts/localization/localized_apis.txt")
        let apis = try String(contentsOf: listURL, encoding: .utf8)
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { NSRegularExpression.escapedPattern(for: String($0.trimmingSuffix(while: { $0 == "(" || $0 == ":" }))) }
        let pattern = #"(?<![\w.])\.?("# + apis.joined(separator: "|") + #")\((?:localized:\s*)?"((?:[^"\\]|\\.)*)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let catalogURL = Self.repoRoot.appendingPathComponent("LoopFollow/Resources/Localizable.xcstrings")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let keys = Set((json["strings"] as? [String: Any])?.keys.map { $0 } ?? [])
        var missing: [String] = []
        for file in try Self.swiftFiles() where !file.path.contains("/LoopFollowLAExtension/") && !file.path.contains("/Shared/") {
            let source = try String(contentsOf: file, encoding: .utf8)
            for m in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let api = Range(m.range(at: 1), in: source), let lit = Range(m.range(at: 2), in: source) else { continue }
                var s = String(source[lit])
                if s.isEmpty || s.contains("\\(") { continue }
                guard let whole = Range(m.range, in: source) else { continue }
                if source[api] == "Text", source[whole.lowerBound...].hasPrefix("Text(verbatim") { continue }
                // "a" + b is String concatenation and never reaches the catalog.
                if source[whole.upperBound...].drop(while: { $0 == " " }).first == "+" { continue }
                s = s.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\n", with: "\n")
                if !keys.contains(s) { missing.append("\(file.lastPathComponent): \(s)") }
            }
        }
        #expect(missing.isEmpty, Comment(rawValue: "Run Scripts/localization/scan_keys.py and translate:\n" + missing.sorted().joined(separator: "\n")))
    }
}

private extension String {
    func trimmingSuffix(while pred: (Character) -> Bool) -> Substring {
        var s = Substring(self)
        while let last = s.last, pred(last) {
            s = s.dropLast()
        }
        return s
    }
}
