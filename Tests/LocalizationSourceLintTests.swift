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

    /// Same rule as Scripts/localization/scan_keys.py: every plain string literal passed as a
    /// direct (labeled or unlabeled) argument of a listed API call must exist as a catalog key.
    /// Labels listed with a leading "!" in localized_apis.txt (systemImage, comment, ...) are skipped,
    /// as are literals inside nested calls or arrays, interpolated literals, and "…" + concatenations.
    @Test("every literal passed to a localized API is a catalog key")
    func scannedLiteralsExistInCatalog() throws {
        let listURL = Self.repoRoot.appendingPathComponent("Scripts/localization/localized_apis.txt")
        var apis: [String] = []
        var ignoredLabels: Set<String> = []
        for raw in try String(contentsOf: listURL, encoding: .utf8).split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("!") { ignoredLabels.insert(String(line.dropFirst())) } else {
                apis.append(String(line.trimmingSuffix(while: { $0 == "(" || $0 == ":" })))
            }
        }
        let pattern = #"(?<![\w.])\.?("# + apis.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + #")\("#
        let regex = try NSRegularExpression(pattern: pattern)
        let catalogURL = Self.repoRoot.appendingPathComponent("LoopFollow/Resources/Localizable.xcstrings")
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let keys = Set((json["strings"] as? [String: Any])?.keys.map { $0 } ?? [])
        var missing: [String] = []
        for file in try Self.swiftFiles() where !file.path.contains("/LoopFollowLAExtension/") && !file.path.contains("/Shared/") {
            let source = try String(contentsOf: file, encoding: .utf8)
            let chars = Array(source)
            for m in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let whole = Range(m.range, in: source), let apiRange = Range(m.range(at: 1), in: source) else { continue }
                if source[apiRange] == "Text", source[whole.lowerBound...].hasPrefix("Text(verbatim") { continue }
                let open = source.distance(from: source.startIndex, to: whole.upperBound) - 1
                for (label, literal, interpolated) in Self.callLiterals(chars, open: open) {
                    if interpolated || literal.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                    if let label, ignoredLabels.contains(label) { continue }
                    let key = literal.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\n", with: "\n")
                    if !keys.contains(key) { missing.append("\(file.lastPathComponent): \(key)") }
                }
            }
        }
        #expect(missing.isEmpty, Comment(rawValue: "Run Scripts/localization/scan_keys.py and translate:\n" + missing.sorted().joined(separator: "\n")))
    }

    /// Direct string-literal arguments of the call whose "(" sits at `open` (index into `chars`).
    /// Mirrors call_literals() in scan_keys.py. A literal followed by "+" is String concatenation.
    private static func callLiterals(_ chars: [Character], open: Int) -> [(String?, String, Bool)] {
        var result: [(String?, String, Bool)] = []
        var i = open + 1
        var depthParen = 0, depthBracket = 0
        var label: String?
        var expectValue = true
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                var j = i + 1
                var interpolated = false
                while j < chars.count, chars[j] != "\"" {
                    if chars[j] == "\\" {
                        if j + 1 < chars.count, chars[j + 1] == "(" { interpolated = true }
                        j += 2
                        continue
                    }
                    j += 1
                }
                let literal = String(chars[(i + 1) ..< min(j, chars.count)])
                var k = j + 1
                while k < chars.count, chars[k] == " " { k += 1 }
                let concatenated = k < chars.count && chars[k] == "+"
                if depthParen == 0, depthBracket == 0, expectValue, !concatenated {
                    result.append((label, literal, interpolated))
                }
                expectValue = false
                i = j + 1
                continue
            }
            switch c {
            case "(": depthParen += 1
            case ")":
                if depthParen == 0 { return result }
                depthParen -= 1
            case "[": depthBracket += 1
            case "]": depthBracket -= 1
            case ",":
                if depthParen == 0, depthBracket == 0 { label = nil; expectValue = true }
            case ":":
                if depthParen == 0, depthBracket == 0, expectValue {
                    var j = i - 1
                    while j >= 0, chars[j] == " " || chars[j] == "\n" { j -= 1 }
                    var name = ""
                    while j >= 0, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { name.insert(chars[j], at: name.startIndex); j -= 1 }
                    label = name.isEmpty ? nil : name
                }
            default:
                if expectValue, !c.isWhitespace {
                    // A value that starts with an identifier is only a label if a ":" follows it.
                    var j = i
                    while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                    var k = j
                    while k < chars.count, chars[k] == " " { k += 1 }
                    if !(j > i && k < chars.count && chars[k] == ":") { expectValue = false }
                }
            }
            i += 1
        }
        return result
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
