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
}
