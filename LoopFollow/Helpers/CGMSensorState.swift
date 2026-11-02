// LoopFollow
// CGMSensorState.swift

import Foundation

/// A CGM state without reliable glucose, as uploaded by Loop or Trio in a
/// Nightscout note of the form "CGM: <state>". The state is the CGM kit's own
/// name, for example "temporarySensorIssue", "warmup" or ".unknown(23)".
struct CGMSensorState: Equatable {
    /// The kit's name for the state.
    let name: String
    let date: Date

    init(name: String, date: Date) {
        self.name = name
        self.date = date
    }

    /// Parses a note text; nil when the note is not a sensor-state note.
    init?(note: String, date: Date) {
        let prefix = "CGM: "
        guard note.hasPrefix(prefix) else { return nil }
        let name = String(note.dropFirst(prefix.count))
        guard !name.isEmpty, !name.contains(where: \.isWhitespace) else { return nil }
        self.init(name: name, date: date)
    }

    /// The state in plain words, e.g. "Temporary sensor issue".
    var displayName: String {
        Self.displayName(for: name)
    }

    /// The state and its time, e.g. "Temporary sensor issue at 22:33".
    var summary: String {
        "\(displayName) at \(date.formatted(date: .omitted, time: .shortened))"
    }

    /// The newest state reported after the newest reading. A reading after a
    /// state means the CGM delivers glucose again, so that state is over.
    static func active(in states: [CGMSensorState], latestBGDate: Date?) -> CGMSensorState? {
        guard let newest = states.max(by: { $0.date < $1.date }) else { return nil }
        if let latestBGDate, newest.date <= latestBGDate {
            return nil
        }
        return newest
    }

    /// Glucose to draw a state's marker at: the last reading at or before the
    /// state, else the first reading after it. `readings` are sorted by date.
    static func anchorSGV(at date: TimeInterval, readings: [ShareGlucoseData]) -> Int? {
        if let before = readings.last(where: { $0.date <= date }) {
            return before.sgv
        }
        return readings.first?.sgv
    }

    static func displayName(for name: String) -> String {
        if name.hasPrefix(".unknown("), name.hasSuffix(")") {
            let code = name.dropFirst(".unknown(".count).dropLast()
            return "Unknown state (\(code))"
        }
        if name == "questionMarks" {
            return "Question marks (???)"
        }

        // G7SensorKit spells some names "Dueto".
        let identifier = name.replacingOccurrences(of: "Dueto", with: "DueTo")

        var words: [String] = []
        var current = ""
        var previous: Character?
        for character in identifier {
            if let previous {
                let startsWord = (character.isUppercase && (previous.isLowercase || previous.isNumber))
                    || (character.isNumber && previous.isLetter)
                if startsWord {
                    words.append(current)
                    current = ""
                }
            }
            current.append(character)
            previous = character
        }
        words.append(current)

        // Acronyms such as "BGs" keep their case.
        let normalized = words.map { word -> String in
            word.dropFirst().contains(where: \.isUppercase) ? word : word.lowercased()
        }
        guard let first = normalized.first, !first.isEmpty else { return name }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + normalized.dropFirst()).joined(separator: " ")
    }
}
