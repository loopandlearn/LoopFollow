// LoopFollow
// CommonMealsManager.swift

import Foundation

struct CommonMeal: Identifiable, Equatable {
    let id = UUID()
    let carbs: Double
    let fat: Double
    let protein: Double
    let bolus: Double

    static func == (lhs: CommonMeal, rhs: CommonMeal) -> Bool {
        lhs.id == rhs.id
    }
}

final class CommonMealsManager: ObservableObject {
    static let shared = CommonMealsManager()

    @Published private(set) var commonMeals: [CommonMeal] = []

    private static let maxEntries = 500
    private static let maxAgeDays = 90.0
    private static let sigma: Double = 60.0
    private static let halfLife: Double = 10.0
    private static let minScore: Double = 0.1
    private static let maxResults = 5

    private init() {}

    // MARK: - Public API

    func recordMeal(carbs: Double, fat: Double = 0, protein: Double = 0, bolus: Double = 0, at date: Date = Date()) {
        let entry = RemoteMealHistoryEntry(carbs: carbs, fat: fat, protein: protein, bolus: bolus, date: date)
        var history = Storage.shared.remoteMealHistory.value
        history.append(entry)
        history = Self.pruned(history, now: date)
        Storage.shared.remoteMealHistory.value = history
    }

    func refresh(now: Date = Date(), carbStep: Double = 1.0, maxCarbs: Double, includeFatProtein: Bool) {
        let history = Storage.shared.remoteMealHistory.value
        commonMeals = Self.computeCommonMeals(
            from: history,
            now: now,
            carbStep: carbStep,
            maxCarbs: maxCarbs,
            includeFatProtein: includeFatProtein
        )
    }

    // MARK: - Scoring (static for testability)

    static func computeCommonMeals(
        from history: [RemoteMealHistoryEntry],
        now: Date,
        carbStep: Double,
        maxCarbs: Double,
        includeFatProtein: Bool
    ) -> [CommonMeal] {
        guard carbStep > 0 else { return [] }

        let nowMinute = {
            let cal = Calendar.current
            return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        }()
        let nowDOW = Calendar.current.component(.weekday, from: now)

        // Group by rounded carbs; track score + best entry (highest scored) for fat/protein
        var groupScores: [Double: Double] = [:]
        var groupBestEntry: [Double: (entry: RemoteMealHistoryEntry, score: Double)] = [:]

        for entry in history {
            let rounded = (entry.carbs / carbStep).rounded() * carbStep
            guard rounded > 0, rounded <= maxCarbs else { continue }

            let t = timeOfDayScore(entryMinute: entry.minuteOfDay, nowMinute: nowMinute)
            let d = dayOfWeekScore(entryDOW: entry.dayOfWeek, nowDOW: nowDOW)
            let daysAgo = now.timeIntervalSince(entry.date) / 86400.0
            let r = recencyScore(daysAgo: daysAgo)

            let score = t * d * r
            groupScores[rounded, default: 0] += score

            if let current = groupBestEntry[rounded] {
                if score > current.score {
                    groupBestEntry[rounded] = (entry, score)
                }
            } else {
                groupBestEntry[rounded] = (entry, score)
            }
        }

        return groupScores
            .filter { $0.value >= minScore }
            .sorted { $0.value > $1.value }
            .prefix(maxResults)
            .map { item in
                let best = groupBestEntry[item.key]?.entry
                return CommonMeal(
                    carbs: item.key,
                    fat: includeFatProtein ? (best?.fat ?? 0) : 0,
                    protein: includeFatProtein ? (best?.protein ?? 0) : 0,
                    bolus: best?.bolus ?? 0
                )
            }
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

    private static func pruned(_ history: [RemoteMealHistoryEntry], now: Date) -> [RemoteMealHistoryEntry] {
        let cutoff = now.addingTimeInterval(-maxAgeDays * 86400)
        var filtered = history.filter { $0.date > cutoff }
        if filtered.count > maxEntries {
            filtered.sort { $0.date > $1.date }
            filtered = Array(filtered.prefix(maxEntries))
        }
        return filtered
    }
}
