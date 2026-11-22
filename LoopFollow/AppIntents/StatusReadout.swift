// LoopFollow
// StatusReadout.swift

import Foundation

struct AlarmStateInput: Equatable {
    var snoozeUntil: Date?
    var muteUntil: Date?
    var soundingAlarmName: String?
}

/// Everything the spoken status needs, captured at one point in time so the
/// formatter is a pure function of its input.
struct StatusReadoutInput {
    /// nil when LoopFollow has never received a glucose reading.
    var snapshot: GlucoseSnapshot?
    /// Epoch seconds of the last completed loop cycle; 0 when unknown.
    var lastLoopTime: TimeInterval
    /// Name of the looping app as reported by Nightscout ("Loop", "Trio", ...).
    var loopAppName: String
    /// False for Dexcom Share followers, who have no loop, pump or treatment data.
    var hasNightscout: Bool
    var alarms: AlarmStateInput
    var now: Date
}

/// A single value a user can ask for. Mirrors `StatusItem` (the Siri-facing enum)
/// so the formatter stays free of AppIntents.
enum StatusField {
    case glucose, delta, iob, cob, basal, predictedGlucose
    case pumpReservoir, pumpBattery, phoneBattery
    case sensorAge, cannulaAge, insulinAge
    case override, tempTarget, profile, lastLoop
    case carbsToday, totalDailyDose, recommendedBolus, alarms
}

enum StatusReadoutFormatter {
    /// A reading at least this old is announced with its age first.
    static let staleAfter: TimeInterval = 12 * 60
    /// Matches the app's "Not Looping" detection.
    static let notLoopingAfter: TimeInterval = 15 * 60
    /// Deltas within this band (mg/dL) are not spoken in the glucose line.
    static let stableDeltaMgdl: Double = 3

    static let noDataText = "LoopFollow has no glucose data yet. Open the app to check its setup."

    // MARK: - Full readout

    static func fullReadout(_ input: StatusReadoutInput) -> String {
        guard let glucose = glucoseLine(input) else { return noDataText }
        var sentences = [glucose]
        if input.hasNightscout {
            sentences.append(contentsOf: [
                iobSentence(input),
                cobSentence(input),
                loopSentence(input),
                overrideSentence(input),
                tempTargetSentence(input),
            ].compactMap { $0 })
        }
        return sentences.joined(separator: " ")
    }

    // MARK: - Glucose

    static func glucoseLine(_ input: StatusReadoutInput) -> String? {
        guard let snapshot = input.snapshot else { return nil }
        let age = readingAge(input)
        var parts = [glucoseValuePhrase(snapshot.glucose, unit: snapshot.unit)]
        if let trend = trendWords(snapshot.trend) {
            parts.append(trend)
        }
        if abs(snapshot.delta) > stableDeltaMgdl {
            parts.append(deltaPhrase(snapshot.delta, unit: snapshot.unit))
        }

        if age >= staleAfter {
            let description = parts.joined(separator: ", ")
            return "The latest reading is \(SpokenDuration.duration(age)) old. It was \(description)."
        }
        parts.append(SpokenDuration.ago(age))
        return "Glucose is \(parts.joined(separator: ", "))."
    }

    /// Glucose in the user's display unit, rounded the way the screen rounds it.
    static func displayValue(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> Double {
        switch unit {
        case .mgdl: return mgdl.rounded()
        case .mmol: return (GlucoseConversion.toMmol(mgdl) * 10).rounded() / 10
        }
    }

    static func formatGlucose(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl: return number(mgdl, fractionDigits: 0)
        case .mmol: return number(GlucoseConversion.toMmol(mgdl), fractionDigits: 1, minimumFractionDigits: 1)
        }
    }

    static func trendWords(_ trend: GlucoseSnapshot.Trend) -> String? {
        switch trend {
        case .upFast: return "rising fast"
        case .up: return "rising"
        case .upSlight: return "rising slowly"
        case .flat: return "steady"
        case .downSlight: return "falling slowly"
        case .down: return "falling"
        case .downFast: return "falling fast"
        case .unknown: return nil
        }
    }

    // MARK: - Single fields

    static func text(for field: StatusField, _ input: StatusReadoutInput) -> String {
        if field == .alarms {
            return alarmSentence(input)
        }
        guard let snapshot = input.snapshot else { return noDataText }

        switch field {
        case .alarms:
            return alarmSentence(input)
        case .glucose:
            return glucoseLine(input) ?? noDataText
        case .delta:
            if snapshot.delta == 0 {
                return "Glucose is unchanged since the previous reading."
            }
            return "Glucose is \(deltaPhrase(snapshot.delta, unit: snapshot.unit)) since the previous reading."
        case .iob:
            return iobSentence(input) ?? "IOB is not available."
        case .cob:
            return cobSentence(input) ?? "COB is not available."
        case .basal:
            return basalSentence(snapshot.basalRate) ?? "The basal rate is not available."
        case .predictedGlucose:
            guard let projected = snapshot.projected else { return "The predicted glucose is not available." }
            return "The predicted glucose is \(formatGlucose(projected, unit: snapshot.unit))."
        case .pumpReservoir:
            guard let units = snapshot.pumpReservoirU else { return "The pump reservoir is above 50 units or not reported." }
            return "The pump reservoir has \(number(units, fractionDigits: 0)) units."
        case .pumpBattery:
            guard let level = snapshot.pumpBattery else { return "The pump battery level is not available." }
            return "The pump battery is at \(number(level, fractionDigits: 0)) percent."
        case .phoneBattery:
            guard let level = snapshot.battery else { return "The looping phone battery level is not available." }
            return "The looping phone battery is at \(number(level, fractionDigits: 0)) percent."
        case .sensorAge:
            return ageSentence("Sensor age", insertTime: snapshot.sageInsertTime, input)
        case .cannulaAge:
            return ageSentence("Cannula age", insertTime: snapshot.cageInsertTime, input)
        case .insulinAge:
            return ageSentence("Insulin age", insertTime: snapshot.iageInsertTime, input)
        case .override:
            return overrideSentence(input) ?? "No override is active."
        case .tempTarget:
            return tempTargetSentence(input) ?? "No temp target is active."
        case .profile:
            guard let name = snapshot.profileName else { return "The profile name is not available." }
            return "The active profile is \(name)."
        case .lastLoop:
            return loopSentence(input) ?? "No loop data is available."
        case .carbsToday:
            guard let grams = snapshot.carbsToday else { return "Carbs today are not available." }
            return "\(number(grams, fractionDigits: 0)) grams of carbs have been entered today."
        case .totalDailyDose:
            guard let tdd = snapshot.tdd else { return "The total daily dose is not available." }
            return "The total daily dose is \(number(tdd, fractionDigits: 1)) units."
        case .recommendedBolus:
            guard let bolus = snapshot.recBolus else { return "No recommended bolus is reported." }
            let app = input.loopAppName.isEmpty ? "The looping app" : input.loopAppName
            return "\(app) reports a recommended bolus of \(number(bolus, fractionDigits: 2)) units. The reading is \(SpokenDuration.duration(readingAge(input))) old."
        }
    }

    // MARK: - Sentences

    static func iobSentence(_ input: StatusReadoutInput) -> String? {
        guard let iob = input.snapshot?.iob else { return nil }
        return "IOB is \(number(iob, fractionDigits: 2)) units."
    }

    static func cobSentence(_ input: StatusReadoutInput) -> String? {
        guard let cob = input.snapshot?.cob else { return nil }
        return "COB is \(number(cob, fractionDigits: 0)) grams."
    }

    static func loopSentence(_ input: StatusReadoutInput) -> String? {
        guard input.hasNightscout, input.lastLoopTime > 0 else { return nil }
        let age = max(input.now.timeIntervalSince1970 - input.lastLoopTime, 0)
        if age >= notLoopingAfter {
            return "The loop hasn't completed in \(SpokenDuration.duration(age))."
        }
        return "The loop last completed \(SpokenDuration.ago(age))."
    }

    static func overrideSentence(_ input: StatusReadoutInput) -> String? {
        guard let snapshot = input.snapshot, let name = snapshot.override else { return nil }
        guard let remaining = remaining(until: snapshot.overrideEndAt, input) else {
            return snapshot.overrideEndAt == nil ? "Override \(name) is active." : nil
        }
        return "Override \(name) is active for another \(remaining)."
    }

    static func tempTargetSentence(_ input: StatusReadoutInput) -> String? {
        guard let snapshot = input.snapshot, let target = snapshot.tempTargetMgdl else { return nil }
        let value = formatGlucose(target, unit: snapshot.unit)
        guard let remaining = remaining(until: snapshot.tempTargetEndAt, input) else {
            return snapshot.tempTargetEndAt == nil ? "A temp target of \(value) is active." : nil
        }
        return "A temp target of \(value) is active for another \(remaining)."
    }

    static func alarmSentence(_ input: StatusReadoutInput) -> String {
        var sentences: [String] = []
        if let until = input.alarms.snoozeUntil, until > input.now {
            sentences.append("All alarms are snoozed until \(SpokenDuration.clockTime(until)).")
        }
        if let until = input.alarms.muteUntil, until > input.now {
            sentences.append("Alarm sounds are muted until \(SpokenDuration.clockTime(until)).")
        }
        if sentences.isEmpty {
            sentences.append("No alarms are snoozed.")
        }
        if let name = input.alarms.soundingAlarmName {
            sentences.append("\(name) is sounding.")
        }
        return sentences.joined(separator: " ")
    }

    /// Spoken form of the stored basal string, which is either "1.2" or
    /// "0.8 → 1.2" (profile rate, then the rate currently running).
    static func basalSentence(_ raw: String, locale: Locale = .current) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.components(separatedBy: "→").map { $0.trimmingCharacters(in: .whitespaces) }
        let parser = NumberFormatter()
        parser.numberStyle = .decimal
        parser.locale = locale
        let values = parts.compactMap { parser.number(from: $0)?.doubleValue }

        guard values.count == parts.count else {
            return "The basal rate is \(trimmed.replacingOccurrences(of: ",", with: ".")) units per hour."
        }
        if values.count == 2 {
            return "The basal rate is \(number(values[1], fractionDigits: 2)) units per hour, temporarily changed from \(number(values[0], fractionDigits: 2))."
        }
        return "The basal rate is \(number(values[0], fractionDigits: 2)) units per hour."
    }

    // MARK: - Helpers

    static func readingAge(_ input: StatusReadoutInput) -> TimeInterval {
        guard let snapshot = input.snapshot else { return 0 }
        return max(input.now.timeIntervalSince(snapshot.updatedAt), 0)
    }

    private static func glucoseValuePhrase(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        if Int(mgdl.rounded()) <= globalVariables.minDisplayGlucose { return "low" }
        if Int(mgdl.rounded()) >= globalVariables.maxDisplayGlucose { return "high" }
        return formatGlucose(mgdl, unit: unit)
    }

    private static func deltaPhrase(_ deltaMgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        let direction = deltaMgdl < 0 ? "down" : "up"
        return "\(direction) \(formatGlucose(abs(deltaMgdl), unit: unit))"
    }

    private static func ageSentence(_ label: String, insertTime: TimeInterval, _ input: StatusReadoutInput) -> String {
        guard insertTime > 0 else { return "\(label) is not set." }
        return "\(label) is \(SpokenDuration.age(since: insertTime, now: input.now))."
    }

    /// Remaining time until an end timestamp; nil when there is no end or it has passed.
    private static func remaining(until endAt: TimeInterval?, _ input: StatusReadoutInput) -> String? {
        guard let endAt else { return nil }
        let remaining = endAt - input.now.timeIntervalSince1970
        guard remaining > 0 else { return nil }
        return SpokenDuration.duration(remaining)
    }

    static func number(_ value: Double, fractionDigits: Int, minimumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = minimumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
