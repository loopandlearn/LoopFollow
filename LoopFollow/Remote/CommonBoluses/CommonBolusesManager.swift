// LoopFollow
// CommonBolusesManager.swift

import Foundation

struct CommonBolus: Identifiable, Equatable {
    let id = UUID()
    let units: Double

    static func == (lhs: CommonBolus, rhs: CommonBolus) -> Bool {
        lhs.id == rhs.id
    }
}

final class CommonBolusesManager: ObservableObject {
    static let shared = CommonBolusesManager()

    @Published private(set) var commonBoluses: [CommonBolus] = []

    private static let maxEntries = 500
    private static let maxAgeDays = 90.0
    private static let sigma: Double = 60.0
    private static let halfLife: Double = 10.0
    private static let minScore: Double = 0.1
    private static let maxResults = 5

    private init() {}

    // MARK: - Public API

    func recordBolus(units: Double, at date: Date = Date()) {
        let entry = RemoteBolusHistoryEntry(units: units, date: date)
        var history = Storage.shared.remoteBolusHistory.value
        history.append(entry)
        history = Self.pruned(history, now: date)
        Storage.shared.remoteBolusHistory.value = history
    }

    func refresh(now: Date = Date(), stepIncrement: Double, maxBolus: Double) {
        let history = Storage.shared.remoteBolusHistory.value
        commonBoluses = Self.computeCommonBoluses(
            from: history,
            now: now,
            stepIncrement: stepIncrement,
            maxBolus: maxBolus
        )
    }

    // MARK: - Scoring (static for testability)

    static func computeCommonBoluses(
        from history: [RemoteBolusHistoryEntry],
        now: Date,
        stepIncrement: Double,
        maxBolus: Double
    ) -> [CommonBolus] {
        guard stepIncrement > 0 else { return [] }

        let nowMinute = {
            let cal = Calendar.current
            return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        }()
        let nowDOW = Calendar.current.component(.weekday, from: now)

        var groups: [Double: Double] = [:]

        for entry in history {
            let rounded = (entry.units / stepIncrement).rounded(.down) * stepIncrement
            let amount = roundToFraction(rounded, stepIncrement: stepIncrement)
            guard amount > 0, amount <= maxBolus else { continue }

            let t = timeOfDayScore(entryMinute: entry.minuteOfDay, nowMinute: nowMinute)
            let d = dayOfWeekScore(entryDOW: entry.dayOfWeek, nowDOW: nowDOW)
            let daysAgo = now.timeIntervalSince(entry.date) / 86400.0
            let r = recencyScore(daysAgo: daysAgo)

            groups[amount, default: 0] += t * d * r
        }

        return groups
            .filter { $0.value >= minScore }
            .sorted { $0.value > $1.value }
            .prefix(maxResults)
            .map { CommonBolus(units: $0.key) }
    }

    static func timeOfDayScore(entryMinute: Int, nowMinute: Int) -> Double {
        let diff = abs(entryMinute - nowMinute)
        let circularDiff = Double(min(diff, 1440 - diff))
        return exp(-(circularDiff * circularDiff) / (2 * sigma * sigma))
    }

    static func dayOfWeekScore(entryDOW: Int, nowDOW: Int) -> Double {
        if entryDOW == nowDOW { return 1.0 }
        let nowWeekend = nowDOW == 1 || nowDOW == 7
        let entryWeekend = entryDOW == 1 || entryDOW == 7
        if nowWeekend == entryWeekend { return 0.7 }
        return 0.15
    }

    static func recencyScore(daysAgo: Double) -> Double {
        pow(0.5, daysAgo / halfLife)
    }

    // MARK: - Helpers

    private static func pruned(_ history: [RemoteBolusHistoryEntry], now: Date) -> [RemoteBolusHistoryEntry] {
        let cutoff = now.addingTimeInterval(-maxAgeDays * 86400)
        var filtered = history.filter { $0.date > cutoff }
        if filtered.count > maxEntries {
            filtered.sort { $0.date > $1.date }
            filtered = Array(filtered.prefix(maxEntries))
        }
        return filtered
    }

    private static func roundToFraction(_ value: Double, stepIncrement: Double) -> Double {
        let digits = fractionDigits(for: stepIncrement)
        let p = pow(10.0, Double(digits))
        return (value * p).rounded() / p
    }

    private static func fractionDigits(for step: Double) -> Int {
        if step >= 1 { return 0 }
        var v = step
        var digits = 0
        while digits < 6, abs(v.rounded() - v) > 1e-10 {
            v *= 10
            digits += 1
        }
        return min(max(digits, 0), 5)
    }
}
